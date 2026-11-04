/**
 * Nightly job: finds open referrals whose follow-up date has passed and that have
 * no open reminder task, then creates one. Schedule with:
 *   System.schedule('Referral reminders', '0 0 6 * * ?', new ReferralReminderBatch());
 */
public with sharing class ReferralReminderBatch implements Database.Batchable<SObject>, Schedulable {
  public static final String SUBJECT = 'Overdue referral follow-up';

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT Id, Name, OwnerId, Patient__c, Priority__c, Due_Date__c
        FROM Referral__c
        WHERE Status__c IN ('Sent', 'Scheduled') AND Due_Date__c < TODAY
      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<Referral__c> scope) {
    Set<Id> alreadyReminded = new Set<Id>();
    String subjectPattern = SUBJECT + '%';
    for (Task t : [
      SELECT WhatId
      FROM Task
      WHERE WhatId IN :scope AND IsClosed = FALSE AND Subject LIKE :subjectPattern
    ]) {
      alreadyReminded.add(t.WhatId);
    }
    List<Task> reminders = new List<Task>();
    for (Referral__c ref : scope) {
      if (!alreadyReminded.contains(ref.Id)) {
        Task t = ReferralTasks.followUpFor(ref, SUBJECT);
        t.ActivityDate = Date.today();
        reminders.add(t);
      }
    }
    Database.SaveResult[] results = Database.insert(reminders, false);
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'Reminder failed for ' +
            reminders[i].WhatId +
            ': ' +
            results[i].getErrors()[0].getMessage()
        );
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
  }

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new ReferralReminderBatch(), 200);
  }
}
