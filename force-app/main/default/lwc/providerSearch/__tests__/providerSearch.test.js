import { createElement } from 'lwc';
import ProviderSearch, { DEBOUNCE_MS } from 'c/providerSearch';
import searchProviders from '@salesforce/apex/ReferralController.searchProviders';

jest.mock(
    '@salesforce/apex/ReferralController.searchProviders',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const PROVIDERS = [
    { Id: '001000000000001', Name: 'Synthetic Heart Clinic', Specialty__c: 'Cardiology', BillingCity: 'Springfield' },
    { Id: '001000000000002', Name: 'Synthetic Neuro Group', Specialty__c: 'Neurology', BillingCity: 'Riverton' }
];
const flush = () => new Promise((r) => setTimeout(r, 0));

describe('c-provider-search', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.useRealTimers();
    });

    function mount() {
        const el = createElement('c-provider-search', { is: ProviderSearch });
        document.body.appendChild(el);
        return el;
    }

    it('debounces the search term before querying', async () => {
        jest.useFakeTimers();
        const el = mount();
        const input = el.shadowRoot.querySelector('[data-id="term"]');
        input.value = 'Synth';
        input.dispatchEvent(new CustomEvent('change'));
        expect(searchProviders.getLastConfig().searchTerm).not.toBe('Synth');
        jest.advanceTimersByTime(DEBOUNCE_MS);
        await Promise.resolve();
        expect(searchProviders.getLastConfig().searchTerm).toBe('Synth');
    });

    it('passes specialty to the query', async () => {
        const el = mount();
        el.shadowRoot.querySelector('[data-id="specialty"]').dispatchEvent(new CustomEvent('change', { detail: { value: 'Cardiology' } }));
        await flush();
        expect(searchProviders.getLastConfig().specialty).toBe('Cardiology');
    });

    it('renders results and fires providerselect', async () => {
        const el = mount();
        searchProviders.emit(PROVIDERS);
        await flush();
        const buttons = el.shadowRoot.querySelectorAll('lightning-button');
        expect(buttons).toHaveLength(2);
        const handler = jest.fn();
        el.addEventListener('providerselect', handler);
        buttons[1].click();
        expect(handler.mock.calls[0][0].detail).toEqual({ providerId: '001000000000002', providerName: 'Synthetic Neuro Group' });
        expect(el.selectedProviderId).toBe('001000000000002');
    });

    it('shows no-results message', async () => {
        const el = mount();
        searchProviders.emit([]);
        await flush();
        expect(el.shadowRoot.querySelector('[data-id="no-results"]')).not.toBeNull();
    });

    it('treats errors as no results', async () => {
        const el = mount();
        searchProviders.error();
        await flush();
        expect(el.shadowRoot.querySelector('[data-id="no-results"]')).not.toBeNull();
    });
});
