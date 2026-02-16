<template>
  <div>
    <label
      v-if="showFieldNames"
      :for="field.uuid"
      class="label text-xl sm:text-2xl py-0 mb-2 sm:mb-3.5 field-name-label"
      :class="{ 'mb-2': !field.description }"
    >
      <MarkdownContent
        v-if="field.title"
        :string="field.title"
      />
      <template v-else>
        {{ field.name || t('verified_phone_number') }}
      </template>
    </label>
    <div
      v-if="field.description"
      dir="auto"
      class="mb-3 px-1 field-description-text"
    >
      <MarkdownContent :string="field.description" />
    </div>
    <div>
      <input
        type="hidden"
        name="normalize_phone"
        value="true"
      >
      <div class="flex w-full rounded-full outline-neutral-content outline-2 outline-offset-2 focus-within:outline phone-number-input-container">
        <div
          id="country_code"
          class="relative inline-block"
        >
          <div class="btn bg-base-200 border border-neutral-300 text-2xl whitespace-nowrap font-normal rounded-l-full country-code-select-label">
            {{ selectedCountry.flag }} +{{ selectedCountry.dial }}
          </div>
          <select
            id="country_code_select"
            class="absolute top-0 bottom-0 right-0 left-0 opacity-0 w-full h-full cursor-pointer"
            :disabled="!!defaultValue"
            @change="onCountrySelect(countries.find((country) => country.flag === $event.target.value))"
          >
            <option
              v-for="(country, index) in countries"
              :key="index"
              :value="country.flag"
            >
              {{ country.flag }} {{ country.name }}
            </option>
          </select>
        </div>
        <input
          :name="`values[${field.uuid}]`"
          :value="fullInternationalPhoneValue"
          hidden
        >
        <input
          :id="field.uuid"
          ref="phone"
          :value="phoneValue"
          :readonly="!!defaultValue"
          class="base-input !text-2xl !rounded-l-none !border-l-0 !outline-none w-full"
          autocomplete="tel"
          type="tel"
          inputmode="tel"
          :required="field.required"
          :pattern="phonePattern"
          placeholder="234 567-8900"
          @input="onPhoneInput"
          @invalid="onInvalid"
          @focus="$emit('focus')"
        >
      </div>
    </div>
  </div>
</template>

<script>
import MarkdownContent from './markdown_content'
import phoneData from './phone_data'
import phoneLengths, { DEFAULT_PHONE_LENGTH } from './phone_lengths'

export default {
  name: 'PhoneStep',
  components: {
    MarkdownContent
  },
  inject: ['t'],
  props: {
    field: {
      type: Object,
      required: true
    },
    showFieldNames: {
      type: Boolean,
      required: false,
      default: true
    },
    modelValue: {
      type: String,
      required: false,
      default: ''
    },
    defaultValue: {
      type: String,
      required: false,
      default: ''
    }
  },
  emits: ['update:model-value', 'focus', 'submit'],
  data () {
    return {
      phoneValue: this.modelValue || this.defaultValue || '',
      selectedCountry: {}
    }
  },
  computed: {
    countries () {
      return phoneData.map(([iso, name, dial, flag, tz]) => {
        return { iso, name, dial, flag, tz }
      })
    },
    countriesDialIndex () {
      return this.countries.reduce((acc, item) => {
        acc[item.dial] ||= item

        return acc
      }, {})
    },
    dialCodesRegexp () {
      const dialCodes = this.countries.map((country) => country.dial).sort((a, b) => b.length - a.length)

      return new RegExp(`^\\+(${dialCodes.join('|')})`)
    },
    detectedPhoneValueDialCode () {
      return (this.phoneValue || '').replace(/[^\d+]/g, '').match(this.dialCodesRegexp)?.[1]
    },
    fullInternationalPhoneValue () {
      if (this.detectedPhoneValueDialCode) {
        return this.phoneValue
      } else if (this.phoneValue) {
        return ['+', this.selectedCountry.dial, this.phoneValue].filter(Boolean).join('')
      } else {
        return ''
      }
    },
    currentDialCode () {
      return this.detectedPhoneValueDialCode || this.selectedCountry?.dial || ''
    },
    localPhoneNumber () {
      // Haal alleen de cijfers uit het telefoonnummer (zonder landcode)
      const digits = (this.phoneValue || '').replace(/[^\d]/g, '')
      const dialCode = this.currentDialCode

      if (!dialCode || !digits) {
        return ''
      }

      // Verwijder de landcode van het begin van het nummer
      if (digits.startsWith(dialCode)) {
        return digits.substring(dialCode.length)
      }

      // Als de landcode niet vooraan staat, is het al het lokale nummer
      return digits
    },
    phoneLengthRules () {
      const dialCode = this.currentDialCode
      return phoneLengths[dialCode] || DEFAULT_PHONE_LENGTH
    },
    isValidPhoneLength () {
      const localNumber = this.localPhoneNumber
      if (!localNumber) {
        return true // Leeg is OK (wordt afgehandeld door required)
      }

      const length = localNumber.length
      const rules = this.phoneLengthRules

      return length >= rules.min && length <= rules.max
    },
    phonePattern () {
      // Dynamische regex pattern gebaseerd op de landcode
      // We gebruiken een flexibele pattern omdat de exacte lengte wordt gecontroleerd in isValidPhoneLength
      // Dit pattern zorgt ervoor dat alleen cijfers, spaties, streepjes en haakjes worden toegestaan
      return '^[\\d\\s\\-\\(\\)]+$'
    },
    validationMessage () {
      if (!this.phoneValue) {
        return ''
      }

      if (!this.isValidPhoneLength) {
        const rules = this.phoneLengthRules
        const countryName = this.selectedCountry?.name || 'dit land'
        return `Het telefoonnummer voor ${countryName} moet tussen ${rules.min} en ${rules.max} cijfers bevatten (zonder landcode)`
      }

      return ''
    }
  },
  mounted () {
    const browserTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone

    if (this.detectedPhoneValueDialCode) {
      this.selectedCountry = this.countriesDialIndex[this.detectedPhoneValueDialCode]
    } else if (browserTimeZone) {
      const tz = browserTimeZone.split('/')[1]

      this.selectedCountry = this.countries.find((country) => country.tz.includes(tz)) || this.countries[0]
    } else {
      // Fallback naar eerste land als er geen timezone is
      this.selectedCountry = this.countries[0] || {}
    }
  },
  methods: {
    onCountrySelect (country) {
      if (country && this.selectedCountry.flag !== country.flag) {
        this.phoneValue = this.phoneValue.replace(`+${this.selectedCountry.dial}`, `+${country.dial}`)
      }

      this.selectedCountry = country || this.countries[0] || {}

      if (this.$refs.phone) {
        this.$refs.phone.focus()
      }
    },
    onPhoneInput (e) {
      this.phoneValue = e.target.value
      this.$emit('update:model-value', this.fullInternationalPhoneValue)

      if (this.detectedPhoneValueDialCode) {
        this.selectedCountry = this.countriesDialIndex[this.detectedPhoneValueDialCode]
      }

      // Valideer en stel custom validity in bij input
      if (this.$refs.phone) {
        if (this.phoneValue && !this.isValidPhoneLength) {
          this.$refs.phone.setCustomValidity(this.validationMessage)
        } else {
          this.$refs.phone.setCustomValidity('')
        }
      }
    },
    onInvalid (e) {
      // Stel custom validity message in op basis van de validatie
      const message = this.validationMessage || ''
      e.target.setCustomValidity(message)
    },
    async submit () {
      this.$emit('update:model-value', this.fullInternationalPhoneValue)
      return Promise.resolve({})
    }
  }
}
</script>
