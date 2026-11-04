import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getReferralsForPatient from '@salesforce/apex/ReferralController.getReferralsForPatient';
import updateStatus from '@salesforce/apex/ReferralController.updateStatus';

const CHANNEL = '/event/Referral_Status_Change__e';

// Mirrors ReferralStatus.cls so the UI only offers valid next steps.
export const NEXT_STATUSES = {
    Draft: ['Sent', 'Cancelled'],
    Sent: ['Scheduled', 'Cancelled'],
    Scheduled: ['Completed', 'Cancelled', 'Sent'],
    Completed: [],
    Cancelled: ['Draft']
};

const COLUMNS = [
    { label: 'Referral', fieldName: 'Name' },
    { label: 'Specialty', fieldName: 'Specialty__c' },
    { label: 'Provider', fieldName: 'providerName' },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Follow-up', fieldName: 'Due_Date__c', type: 'date-local', cellAttributes: { class: { fieldName: 'dueClass' } } },
    { type: 'action', typeAttributes: { rowActions: (row, done) => done(row.actions) } }
];

export default class ReferralTracker extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    rows = [];
    error;
    wiredResult;
    subscription;

    @wire(getReferralsForPatient, { patientId: '$recordId' })
    wiredReferrals(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data.map((r) => this.toRow(r));
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = reduceError(error);
        }
    }

    connectedCallback() {
        onError(() => {
            // Live updates are optional; the component still works with manual refresh.
        });
        subscribe(CHANNEL, -1, (message) => this.handleEvent(message)).then((sub) => {
            this.subscription = sub;
        });
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    get hasReferrals() {
        return this.rows.length > 0;
    }

    get openCount() {
        return this.rows.filter((r) => r.isOpen).length;
    }

    get overdueCount() {
        return this.rows.filter((r) => r.isOverdue).length;
    }

    toRow(r) {
        const isOpen = r.Status__c !== 'Completed' && r.Status__c !== 'Cancelled';
        const isOverdue = isOpen && !!r.Due_Date__c && r.Due_Date__c < todayIso();
        return {
            ...r,
            providerName: r.Provider__r ? r.Provider__r.Name : '',
            isOpen,
            isOverdue,
            dueClass: isOverdue ? 'slds-text-color_error' : '',
            actions: (NEXT_STATUSES[r.Status__c] || []).map((s) => ({ label: `Mark ${s}`, name: s }))
        };
    }

    handleEvent(message) {
        const payload = message && message.data && message.data.payload;
        if (payload && payload.Patient_Id__c && payload.Patient_Id__c.substring(0, 15) === String(this.recordId).substring(0, 15)) {
            this.handleRefresh();
        }
    }

    async handleRowAction(event) {
        const status = event.detail.action.name;
        const row = event.detail.row;
        try {
            await updateStatus({ referralId: row.Id, newStatus: status });
            this.dispatchEvent(new ShowToastEvent({ title: 'Referral updated', message: `${row.Name} is now ${status}.`, variant: 'success' }));
            await this.handleRefresh();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Could not update referral', message: reduceError(e), variant: 'error' }));
        }
    }

    handleRefresh() {
        return refreshApex(this.wiredResult);
    }
}

function todayIso() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function reduceError(error) {
    if (!error) return 'Unknown error';
    if (error.body && typeof error.body.message === 'string') return error.body.message;
    if (typeof error.message === 'string') return error.message;
    return 'Unknown error';
}
