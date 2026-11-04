import { LightningElement, api, wire } from 'lwc';
import searchProviders from '@salesforce/apex/ReferralController.searchProviders';

export const DEBOUNCE_MS = 300;
const SPECIALTIES = ['Cardiology', 'Dermatology', 'Endocrinology', 'Gastroenterology', 'Neurology', 'Orthopedics', 'Behavioral Health', 'Physical Therapy'];

/**
 * Debounced provider search. Fires a `providerselect` event with { providerId, providerName }
 * and exposes the selection as an output property when used on a Flow screen.
 */
export default class ProviderSearch extends LightningElement {
    _selectedProviderId;

    @api
    get selectedProviderId() {
        return this._selectedProviderId;
    }
    set selectedProviderId(value) {
        this._selectedProviderId = value;
    }

    searchTerm = '';
    specialty = '';
    queryTerm = '';
    providers = [];
    searched = false;
    timer;

    specialtyOptions = [{ label: 'Any specialty', value: '' }, ...SPECIALTIES.map((s) => ({ label: s, value: s }))];

    @wire(searchProviders, { searchTerm: '$queryTerm', specialty: '$specialty' })
    wiredProviders({ data, error }) {
        if (data) {
            this.providers = data;
            this.searched = true;
        } else if (error) {
            this.providers = [];
            this.searched = true;
        }
    }

    get hasResults() {
        return this.providers.length > 0;
    }

    handleTermChange(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this.timer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.timer = setTimeout(() => {
            this.queryTerm = this.searchTerm;
        }, DEBOUNCE_MS);
    }

    handleSpecialtyChange(event) {
        this.specialty = event.detail.value;
    }

    handleSelect(event) {
        const id = event.target.dataset.id;
        const provider = this.providers.find((p) => p.Id === id);
        this._selectedProviderId = id;
        this.dispatchEvent(new CustomEvent('providerselect', { detail: { providerId: id, providerName: provider ? provider.Name : '' } }));
    }
}
