/** Builds follow-up Tasks for referrals. */
public inherited sharing class ReferralTasks {
  public static Task followUpFor(Referral__c ref, String subject) {
    Date due = ref.Due_Date__c != null ? ref.Due_Date__c : Date.today().addDays(7);
    return new Task(
      WhatId = ref.Id,
      WhoId = ref.Patient__c,
      OwnerId = ref.OwnerId,
      Subject = subject + ' - ' + ref.Name,
      ActivityDate = due,
      Priority = ref.Priority__c == 'Routine' ? 'Normal' : 'High',
      Status = 'Not Started'
    );
  }
}
