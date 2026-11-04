@IsTest
private class ReferralAgentActions_Test {
  @IsTest
  static void summarizesOpenAndOverdueReferrals() {
    Contact p = ReferralTestData.patient();
    Account prov = ReferralTestData.provider('Synthetic Heart Clinic', 'Cardiology');
    ReferralTestData.referral(p.Id, prov.Id, ReferralStatus.SENT, Date.today().addDays(-1));
    ReferralTestData.referral(p.Id, prov.Id, null, Date.today().addDays(4));
    ReferralTestData.referral(p.Id, prov.Id, ReferralStatus.COMPLETED, null);

    GetReferralSummaryAction.Request req = new GetReferralSummaryAction.Request();
    req.patientId = p.Id;
    GetReferralSummaryAction.Response resp = GetReferralSummaryAction.summarize(
      new List<GetReferralSummaryAction.Request>{ req }
    )[0];

    Assert.areEqual(2, resp.openCount);
    Assert.areEqual(1, resp.overdueCount);
    Assert.isTrue(resp.summary.contains('Synthetic Heart Clinic'));
  }

  @IsTest
  static void summaryHandlesPatientWithNoReferrals() {
    Contact p = ReferralTestData.patient();
    GetReferralSummaryAction.Request req = new GetReferralSummaryAction.Request();
    req.patientId = p.Id;
    Assert.areEqual(
      'No open referrals.',
      GetReferralSummaryAction.summarize(new List<GetReferralSummaryAction.Request>{ req })[0]
        .summary
    );
  }

  @IsTest
  static void createsFollowUpTask() {
    Contact p = ReferralTestData.patient();
    Referral__c r = ReferralTestData.referral(p.Id, null, null, null);
    CreateReferralFollowUpAction.Request req = new CreateReferralFollowUpAction.Request();
    req.referralId = r.Id;
    req.subject = 'Call cardiology office';
    req.dueDate = Date.today().addDays(2);

    CreateReferralFollowUpAction.Response resp = CreateReferralFollowUpAction.create(
      new List<CreateReferralFollowUpAction.Request>{ req }
    )[0];
    Assert.isNotNull(resp.taskId);
    Task t = [SELECT ActivityDate, Subject FROM Task WHERE Id = :resp.taskId];
    Assert.areEqual(Date.today().addDays(2), t.ActivityDate);
  }

  @IsTest
  static void reportsMissingReferral() {
    Contact p = ReferralTestData.patient();
    Referral__c r = ReferralTestData.referral(p.Id, null, null, null);
    Id missingId = r.Id;
    delete r;
    CreateReferralFollowUpAction.Request req = new CreateReferralFollowUpAction.Request();
    req.referralId = missingId;
    req.subject = 'x';
    CreateReferralFollowUpAction.Response resp = CreateReferralFollowUpAction.create(
      new List<CreateReferralFollowUpAction.Request>{ req }
    )[0];
    Assert.isNull(resp.taskId);
    Assert.isTrue(resp.message.contains('not found'));
  }
}
