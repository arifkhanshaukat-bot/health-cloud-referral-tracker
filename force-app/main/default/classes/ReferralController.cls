/** Thin @AuraEnabled facade for the LWCs. Converts exceptions to user-friendly messages. */
public with sharing class ReferralController {
  @AuraEnabled(cacheable=true)
  public static List<Referral__c> getReferralsForPatient(Id patientId) {
    try {
      return ReferralService.getReferralsForPatient(patientId);
    } catch (Exception ex) {
      throw toAuraException(ex);
    }
  }

  @AuraEnabled
  public static Referral__c updateStatus(Id referralId, String newStatus) {
    try {
      return ReferralService.updateStatus(referralId, newStatus);
    } catch (Exception ex) {
      throw toAuraException(ex);
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Account> searchProviders(String searchTerm, String specialty) {
    try {
      return ReferralService.searchProviders(searchTerm, specialty);
    } catch (Exception ex) {
      throw toAuraException(ex);
    }
  }

  private static AuraHandledException toAuraException(Exception ex) {
    String message = ex instanceof ReferralService.ReferralException
      ? ex.getMessage()
      : 'Something went wrong. Please try again or contact support.';
    AuraHandledException aex = new AuraHandledException(message);
    aex.setMessage(message);
    return aex;
  }
}
