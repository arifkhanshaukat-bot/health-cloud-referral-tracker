/** Allowed referral status transitions, kept in one place so UI, API and triggers agree. */
public inherited sharing class ReferralStatus {
  public static final String DRAFT = 'Draft';
  public static final String SENT = 'Sent';
  public static final String SCHEDULED = 'Scheduled';
  public static final String COMPLETED = 'Completed';
  public static final String CANCELLED = 'Cancelled';

  private static final Map<String, Set<String>> ALLOWED = new Map<String, Set<String>>{
    DRAFT => new Set<String>{ SENT, CANCELLED },
    SENT => new Set<String>{ SCHEDULED, CANCELLED },
    SCHEDULED => new Set<String>{ COMPLETED, CANCELLED, SENT },
    COMPLETED => new Set<String>(),
    CANCELLED => new Set<String>{ DRAFT }
  };

  public static Boolean canTransition(String fromStatus, String toStatus) {
    if (fromStatus == toStatus) {
      return true;
    }
    return ALLOWED.containsKey(fromStatus) && ALLOWED.get(fromStatus).contains(toStatus);
  }

  public static Boolean isOpen(String status) {
    return status != COMPLETED && status != CANCELLED;
  }
}
