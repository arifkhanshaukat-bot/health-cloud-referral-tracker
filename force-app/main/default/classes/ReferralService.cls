/**
 * Business logic for referrals. All queries run in user mode so sharing,
 * object and field permissions are enforced for the running user.
 */
public with sharing class ReferralService {
  public class ReferralException extends Exception {
  }

  public static List<Referral__c> getReferralsForPatient(Id patientId) {
    return [
      SELECT
        Id,
        Name,
        Status__c,
        Priority__c,
        Specialty__c,
        Due_Date__c,
        Status_Changed_At__c,
        Provider__c,
        Provider__r.Name
      FROM Referral__c
      WHERE Patient__c = :patientId
      WITH USER_MODE
      ORDER BY Due_Date__c ASC NULLS LAST, CreatedDate DESC
      LIMIT 200
    ];
  }

  public static Referral__c updateStatus(Id referralId, String newStatus) {
    List<Referral__c> found = [
      SELECT Id, Status__c
      FROM Referral__c
      WHERE Id = :referralId
      WITH USER_MODE
      LIMIT 1
    ];
    if (found.isEmpty()) {
      throw new ReferralException('Referral not found or not accessible.');
    }
    Referral__c ref = found[0];
    if (!ReferralStatus.canTransition(ref.Status__c, newStatus)) {
      throw new ReferralException(
        'A referral cannot move from ' + ref.Status__c + ' to ' + newStatus + '.'
      );
    }
    ref.Status__c = newStatus;
    update as user ref;
    return ref;
  }

  public static List<Account> searchProviders(String searchTerm, String specialty) {
    String term = String.isBlank(searchTerm) ? '%' : '%' + searchTerm.trim() + '%';
    if (String.isBlank(specialty)) {
      return [
        SELECT Id, Name, Specialty__c, BillingCity, Phone
        FROM Account
        WHERE Accepting_Referrals__c = TRUE AND Name LIKE :term
        WITH USER_MODE
        ORDER BY Name
        LIMIT 25
      ];
    }
    return [
      SELECT Id, Name, Specialty__c, BillingCity, Phone
      FROM Account
      WHERE Accepting_Referrals__c = TRUE AND Name LIKE :term AND Specialty__c = :specialty
      WITH USER_MODE
      ORDER BY Name
      LIMIT 25
    ];
  }
}
