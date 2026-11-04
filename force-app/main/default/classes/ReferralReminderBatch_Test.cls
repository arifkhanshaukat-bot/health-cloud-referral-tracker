@IsTest
private class ReferralReminderBatch_Test {
  @IsTest
  static void createsOneReminderPerOverdueReferral() {
    Contact p = ReferralTestData.patient();
    Referral__c overdue = ReferralTestData.referral(
      p.Id,
      null,
      ReferralStatus.SENT,
      Date.today().addDays(-3)
    );
    Referral__c future = ReferralTestData.referral(
      p.Id,
      null,
      ReferralStatus.SENT,
      Date.today().addDays(3)
    );

    Test.startTest();
    Database.executeBatch(new ReferralReminderBatch());
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Task WHERE WhatId = :overdue.Id AND Subject LIKE 'Overdue%']
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Task WHERE WhatId = :future.Id AND Subject LIKE 'Overdue%']
    );
  }

  @IsTest
  static void doesNotDuplicateReminders() {
    Contact p = ReferralTestData.patient();
    Referral__c overdue = ReferralTestData.referral(
      p.Id,
      null,
      ReferralStatus.SENT,
      Date.today().addDays(-3)
    );
    ReferralReminderBatch job = new ReferralReminderBatch();
    List<Referral__c> scope = [
      SELECT Id, Name, OwnerId, Patient__c, Priority__c, Due_Date__c
      FROM Referral__c
      WHERE Id = :overdue.Id
    ];
    job.execute(null, scope);
    job.execute(null, scope);
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Task WHERE WhatId = :overdue.Id AND Subject LIKE 'Overdue%']
    );
  }

  @IsTest
  static void schedules() {
    Test.startTest();
    String jobId = System.schedule('test reminders', '0 0 6 * * ?', new ReferralReminderBatch());
    Test.stopTest();
    Assert.isNotNull(jobId);
  }
}
