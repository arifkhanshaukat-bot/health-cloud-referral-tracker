@IsTest
private class ReferralService_Test {
  @IsTest
  static void returnsReferralsForPatientOrderedByDueDate() {
    Contact p = ReferralTestData.patient();
    Account prov = ReferralTestData.provider('Synthetic Heart Clinic', 'Cardiology');
    ReferralTestData.referral(p.Id, prov.Id, null, Date.today().addDays(10));
    ReferralTestData.referral(p.Id, prov.Id, null, Date.today().addDays(2));

    List<Referral__c> refs = ReferralService.getReferralsForPatient(p.Id);
    Assert.areEqual(2, refs.size());
    Assert.isTrue(refs[0].Due_Date__c < refs[1].Due_Date__c, 'Soonest due date first');
  }

  @IsTest
  static void validTransitionPublishesEventAndCreatesTask() {
    Contact p = ReferralTestData.patient();
    Referral__c r = ReferralTestData.referral(p.Id, null, null, Date.today().addDays(5));

    Test.startTest();
    ReferralService.updateStatus(r.Id, ReferralStatus.SENT);
    Test.stopTest();

    Referral__c updated = [
      SELECT Status__c, Status_Changed_At__c
      FROM Referral__c
      WHERE Id = :r.Id
    ];
    Assert.areEqual(ReferralStatus.SENT, updated.Status__c);
    Assert.isNotNull(updated.Status_Changed_At__c);
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Task WHERE WhatId = :r.Id],
      'Follow-up task expected when Sent'
    );
  }

  @IsTest
  static void invalidTransitionIsRejected() {
    Contact p = ReferralTestData.patient();
    Referral__c r = ReferralTestData.referral(p.Id, null, null, null);
    try {
      ReferralService.updateStatus(r.Id, ReferralStatus.COMPLETED);
      Assert.fail('Draft -> Completed should be rejected');
    } catch (ReferralService.ReferralException ex) {
      Assert.isTrue(ex.getMessage().contains('cannot move'));
    }
  }

  @IsTest
  static void triggerBlocksInvalidTransitionInBulk() {
    Contact p = ReferralTestData.patient();
    List<Referral__c> refs = new List<Referral__c>();
    for (Integer i = 0; i < 200; i++) {
      refs.add(new Referral__c(Patient__c = p.Id, Specialty__c = 'Neurology'));
    }
    insert refs;
    for (Referral__c r : refs) {
      r.Status__c = ReferralStatus.COMPLETED;
    }
    List<Database.SaveResult> results = Database.update(refs, false);
    for (Database.SaveResult sr : results) {
      Assert.isFalse(sr.isSuccess(), 'Every invalid transition should fail');
    }
  }

  @IsTest
  static void searchesProvidersBySpecialty() {
    ReferralTestData.provider('Synthetic Heart Clinic', 'Cardiology');
    ReferralTestData.provider('Synthetic Skin Center', 'Dermatology');
    Assert.areEqual(1, ReferralService.searchProviders('Synthetic', 'Cardiology').size());
    Assert.areEqual(2, ReferralService.searchProviders('Synthetic', null).size());
    Assert.areEqual(2, ReferralService.searchProviders('', null).size());
  }

  @IsTest
  static void controllerWrapsErrors() {
    Contact p = ReferralTestData.patient();
    Referral__c r = ReferralTestData.referral(p.Id, null, null, null);
    try {
      ReferralController.updateStatus(r.Id, ReferralStatus.COMPLETED);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException ex) {
      Assert.isTrue(ex.getMessage().contains('cannot move'));
    }
    Assert.areEqual(1, ReferralController.getReferralsForPatient(p.Id).size());
    Assert.areEqual(0, ReferralController.searchProviders('Nobody', null).size());
  }

  @IsTest
  static void statusRules() {
    Assert.isTrue(ReferralStatus.canTransition('Draft', 'Draft'));
    Assert.isFalse(ReferralStatus.canTransition('Completed', 'Draft'));
    Assert.isTrue(ReferralStatus.isOpen('Sent'));
    Assert.isFalse(ReferralStatus.isOpen('Cancelled'));
  }
}
