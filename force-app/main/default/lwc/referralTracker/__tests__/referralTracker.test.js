import { createElement } from 'lwc';
import ReferralTracker, { NEXT_STATUSES, reduceError } from 'c/referralTracker';
import getReferralsForPatient from '@salesforce/apex/ReferralController.getReferralsForPatient';
import updateStatus from '@salesforce/apex/ReferralController.updateStatus';
import { subscribe } from 'lightning/empApi';

jest.mock(
    '@salesforce/apex/ReferralController.getReferralsForPatient',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock('@salesforce/apex/ReferralController.updateStatus', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex', () => ({ refreshApex: jest.fn(() => Promise.resolve()) }), { virtual: true });

// Synthetic records only.
const REFERRALS = [
    { Id: 'a01000000000001', Name: 'REF-00001', Status__c: 'Sent', Specialty__c: 'Cardiology', Due_Date__c: '2000-01-01', Provider__r: { Name: 'Synthetic Heart Clinic' } },
    { Id: 'a01000000000002', Name: 'REF-00002', Status__c: 'Draft', Specialty__c: 'Neurology', Due_Date__c: '2999-01-01' },
    { Id: 'a01000000000003', Name: 'REF-00003', Status__c: 'Completed', Specialty__c: 'Dermatology' }
];

const flush = () => new Promise((r) => setTimeout(r, 0));

function mount() {
    const el = createElement('c-referral-tracker', { is: ReferralTracker });
    el.recordId = '003000000000001';
    document.body.appendChild(el);
    return el;
}

describe('c-referral-tracker', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('renders rows with open/overdue summary', async () => {
        const el = mount();
        getReferralsForPatient.emit(REFERRALS);
        await flush();
        const table = el.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(3);
        expect(table.data[0].providerName).toBe('Synthetic Heart Clinic');
        expect(table.data[0].isOverdue).toBe(true);
        expect(table.data[1].isOverdue).toBe(false);
        expect(table.data[2].actions).toEqual([]);
        expect(el.shadowRoot.querySelector('[data-id="summary"]').textContent).toContain('2 open');
        expect(el.shadowRoot.querySelector('[data-id="summary"]').textContent).toContain('1 overdue');
    });

    it('offers only valid next statuses as row actions', async () => {
        const el = mount();
        getReferralsForPatient.emit(REFERRALS);
        await flush();
        const row = el.shadowRoot.querySelector('lightning-datatable').data[1];
        expect(row.actions.map((a) => a.name)).toEqual(NEXT_STATUSES.Draft);
    });

    it('shows empty state', async () => {
        const el = mount();
        getReferralsForPatient.emit([]);
        await flush();
        expect(el.shadowRoot.querySelector('[data-id="empty"]')).not.toBeNull();
    });

    it('shows wire errors', async () => {
        const el = mount();
        getReferralsForPatient.error({ message: 'No access' });
        await flush();
        expect(el.shadowRoot.querySelector('[data-id="error"]')).not.toBeNull();
    });

    it('calls Apex on row action and toasts success', async () => {
        updateStatus.mockResolvedValue({});
        const el = mount();
        getReferralsForPatient.emit(REFERRALS);
        await flush();
        const toast = jest.fn();
        el.addEventListener('lightning__showtoast', toast);
        el.shadowRoot.querySelector('lightning-datatable').dispatchEvent(
            new CustomEvent('rowaction', { detail: { action: { name: 'Sent' }, row: REFERRALS[1] } })
        );
        await flush();
        expect(updateStatus).toHaveBeenCalledWith({ referralId: 'a01000000000002', newStatus: 'Sent' });
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
    });

    it('toasts the server message when Apex rejects the change', async () => {
        updateStatus.mockRejectedValue({ body: { message: 'A referral cannot move from Draft to Completed.' } });
        const el = mount();
        getReferralsForPatient.emit(REFERRALS);
        await flush();
        const toast = jest.fn();
        el.addEventListener('lightning__showtoast', toast);
        el.shadowRoot.querySelector('lightning-datatable').dispatchEvent(
            new CustomEvent('rowaction', { detail: { action: { name: 'Completed' }, row: REFERRALS[1] } })
        );
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('cannot move');
    });

    it('subscribes to the status-change platform event', () => {
        mount();
        expect(subscribe).toHaveBeenCalledWith('/event/Referral_Status_Change__e', -1, expect.any(Function));
    });

    it('reduceError handles common shapes', () => {
        expect(reduceError({ body: { message: 'x' } })).toBe('x');
        expect(reduceError(new Error('y'))).toBe('y');
        expect(reduceError(null)).toBe('Unknown error');
    });
});
