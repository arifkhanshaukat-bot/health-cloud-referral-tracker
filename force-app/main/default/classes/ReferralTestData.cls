/** Synthetic test data factory. No real people, providers or identifiers. */
@IsTest
public class ReferralTestData {
  public static Contact patient() {
    Contact c = new Contact(FirstName = 'Test', LastName = 'Patient ' + Crypto.getRandomInteger());
    insert c;
    return c;
  }

  public static Account provider(String name, String specialty) {
    Account a = new Account(Name = name, Specialty__c = specialty, Accepting_Referrals__c = true);
    insert a;
    return a;
  }

  public static Referral__c referral(Id patientId, Id providerId, String status, Date due) {
    Referral__c r = new Referral__c(
      Patient__c = patientId,
      Provider__c = providerId,
      Specialty__c = 'Cardiology',
      Priority__c = 'Routine',
      Due_Date__c = due
    );
    insert r;
    if (status != null && status != ReferralStatus.DRAFT) {
      // walk the allowed path so trigger validation passes
      List<String> path = new List<String>{
        ReferralStatus.SENT,
        ReferralStatus.SCHEDULED,
        ReferralStatus.COMPLETED
      };
      for (String step : path) {
        r.Status__c = step;
        update r;
        if (step == status) {
          break;
        }
      }
    }
    return r;
  }
}
