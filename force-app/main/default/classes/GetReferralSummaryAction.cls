/**
 * Agentforce / Flow action: returns a plain-language summary of a patient's open
 * referrals so an agent (or a Flow screen) can answer "Where do my referrals stand?".
 * Register it as an agent action in Agentforce Builder; the labels and descriptions
 * below are what the planner reads when deciding to call it.
 */
public with sharing class GetReferralSummaryAction {
  public class Request {
    @InvocableVariable(
      label='Patient Contact Id'
      description='Id of the patient Contact record'
      required=true
    )
    public Id patientId;
  }

  public class Response {
    @InvocableVariable(
      label='Open referral count'
      description='Number of referrals not yet completed or cancelled'
    )
    public Integer openCount;
    @InvocableVariable(
      label='Overdue referral count'
      description='Open referrals whose follow-up date has passed'
    )
    public Integer overdueCount;
    @InvocableVariable(
      label='Summary'
      description='Plain-language summary, one line per open referral'
    )
    public String summary;
  }

  @InvocableMethod(
    label='Get Patient Referral Summary'
    description='Summarizes a patient\'s open referrals, including provider, specialty, status and follow-up date.'
    category='Referrals'
  )
  public static List<Response> summarize(List<Request> requests) {
    Set<Id> patientIds = new Set<Id>();
    for (Request r : requests) {
      patientIds.add(r.patientId);
    }
    Map<Id, List<Referral__c>> byPatient = new Map<Id, List<Referral__c>>();
    for (Referral__c ref : [
      SELECT Patient__c, Name, Status__c, Specialty__c, Due_Date__c, Provider__r.Name
      FROM Referral__c
      WHERE Patient__c IN :patientIds AND Status__c NOT IN ('Completed', 'Cancelled')
      WITH USER_MODE
      ORDER BY Due_Date__c ASC NULLS LAST
    ]) {
      if (!byPatient.containsKey(ref.Patient__c)) {
        byPatient.put(ref.Patient__c, new List<Referral__c>());
      }
      byPatient.get(ref.Patient__c).add(ref);
    }

    List<Response> responses = new List<Response>();
    for (Request r : requests) {
      List<Referral__c> refs = byPatient.containsKey(r.patientId)
        ? byPatient.get(r.patientId)
        : new List<Referral__c>();
      Response resp = new Response();
      resp.openCount = refs.size();
      resp.overdueCount = 0;
      List<String> lines = new List<String>();
      for (Referral__c ref : refs) {
        Boolean overdue = ref.Due_Date__c != null && ref.Due_Date__c < Date.today();
        if (overdue) {
          resp.overdueCount++;
        }
        lines.add(
          ref.Name +
            ': ' +
            (ref.Specialty__c == null ? 'Referral' : ref.Specialty__c) +
            (ref.Provider__r == null ? '' : ' with ' + ref.Provider__r.Name) +
            ' is ' +
            ref.Status__c +
            (ref.Due_Date__c == null
              ? ''
              : ', follow-up ' + (overdue ? 'overdue since ' : 'due ') + ref.Due_Date__c.format())
        );
      }
      resp.summary = lines.isEmpty() ? 'No open referrals.' : String.join(lines, '\n');
      responses.add(resp);
    }
    return responses;
  }
}
