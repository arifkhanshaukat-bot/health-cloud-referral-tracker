/**
 * Referral trigger logic. Kept framework-free so this repo deploys on its own;
 * in a real org it would extend the handler base class from
 * salesforce-apex-trigger-framework.
 */
public with sharing class ReferralTriggerHandler {
  public static void beforeInsert(List<Referral__c> newRecords) {
    for (Referral__c ref : newRecords) {
      if (ref.Status__c == null) {
        ref.Status__c = ReferralStatus.DRAFT;
      }
      ref.Status_Changed_At__c = System.now();
    }
  }

  public static void beforeUpdate(List<Referral__c> newRecords, Map<Id, Referral__c> oldMap) {
    for (Referral__c ref : newRecords) {
      Referral__c old = oldMap.get(ref.Id);
      if (ref.Status__c == old.Status__c) {
        continue;
      }
      if (!ReferralStatus.canTransition(old.Status__c, ref.Status__c)) {
        ref.Status__c.addError(
          'A referral cannot move from ' + old.Status__c + ' to ' + ref.Status__c + '.'
        );
        continue;
      }
      ref.Status_Changed_At__c = System.now();
    }
  }

  public static void afterUpdate(List<Referral__c> newRecords, Map<Id, Referral__c> oldMap) {
    List<Referral_Status_Change__e> events = new List<Referral_Status_Change__e>();
    List<Task> followUps = new List<Task>();
    for (Referral__c ref : newRecords) {
      Referral__c old = oldMap.get(ref.Id);
      if (ref.Status__c == old.Status__c) {
        continue;
      }
      events.add(
        new Referral_Status_Change__e(
          Referral_Id__c = ref.Id,
          Patient_Id__c = ref.Patient__c,
          Old_Status__c = old.Status__c,
          New_Status__c = ref.Status__c
        )
      );
      if (ref.Status__c == ReferralStatus.SENT) {
        followUps.add(ReferralTasks.followUpFor(ref, 'Confirm appointment scheduled'));
      }
    }
    if (!events.isEmpty()) {
      EventBus.publish(events);
    }
    if (!followUps.isEmpty()) {
      insert as user followUps;
    }
  }
}
