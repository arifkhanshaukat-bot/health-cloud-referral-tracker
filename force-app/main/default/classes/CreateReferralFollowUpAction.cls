/**
 * Agentforce / Flow action: creates a follow-up task on a referral, e.g. when a care
 * coordinator asks the agent to "remind me to call the cardiology office on Friday".
 */
public with sharing class CreateReferralFollowUpAction {
  public class Request {
    @InvocableVariable(label='Referral Id' required=true)
    public Id referralId;
    @InvocableVariable(
      label='Subject'
      description='Short description of the follow-up'
      required=true
    )
    public String subject;
    @InvocableVariable(
      label='Due date'
      description='When the follow-up is due. Defaults to 7 days from today.'
    )
    public Date dueDate;
  }

  public class Response {
    @InvocableVariable(label='Task Id')
    public Id taskId;
    @InvocableVariable(label='Message')
    public String message;
  }

  @InvocableMethod(
    label='Create Referral Follow-up'
    description='Creates a follow-up task on a referral for the referral owner.'
    category='Referrals'
  )
  public static List<Response> create(List<Request> requests) {
    Set<Id> ids = new Set<Id>();
    for (Request r : requests) {
      ids.add(r.referralId);
    }
    Map<Id, Referral__c> refs = new Map<Id, Referral__c>(
      [
        SELECT Id, Name, OwnerId, Patient__c, Priority__c, Due_Date__c
        FROM Referral__c
        WHERE Id IN :ids
        WITH USER_MODE
      ]
    );
    List<Task> tasks = new List<Task>();
    List<Response> responses = new List<Response>();
    for (Request r : requests) {
      Response resp = new Response();
      Referral__c ref = refs.get(r.referralId);
      if (ref == null) {
        resp.message = 'Referral not found or you do not have access to it.';
        tasks.add(null);
      } else {
        Task t = ReferralTasks.followUpFor(ref, r.subject.left(200));
        t.ActivityDate = r.dueDate != null ? r.dueDate : Date.today().addDays(7);
        tasks.add(t);
      }
      responses.add(resp);
    }
    List<Task> toInsert = new List<Task>();
    for (Task t : tasks) {
      if (t != null) {
        toInsert.add(t);
      }
    }
    insert as user toInsert;
    for (Integer i = 0; i < tasks.size(); i++) {
      if (tasks[i] != null) {
        responses[i].taskId = tasks[i].Id;
        responses[i].message = 'Follow-up created for ' + tasks[i].ActivityDate.format() + '.';
      }
    }
    return responses;
  }
}
