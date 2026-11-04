trigger ReferralTrigger on Referral__c(before insert, before update, after update) {
  switch on Trigger.operationType {
    when BEFORE_INSERT {
      ReferralTriggerHandler.beforeInsert(Trigger.new);
    }
    when BEFORE_UPDATE {
      ReferralTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    when AFTER_UPDATE {
      ReferralTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
  }
}
