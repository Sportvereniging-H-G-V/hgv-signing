<template>
  <form
    ref="form"
    action="post"
    method="post"
    class="mx-auto"
    @submit.prevent="submit"
  >
    <input
      type="hidden"
      name="authenticity_token"
      :value="authenticityToken"
    >
    <div
      v-for="(submitter, index) in [...submitters, ...optionalSubmitters]"
      :key="submitter.uuid"
      :class="{ 'mt-4': index !== 0 }"
    >
      <input
        :value="submitter.uuid"
        hidden
        name="submission[submitters][][uuid]"
      >
      <label
        :for="submitter.uuid"
        dir="auto"
        class="label text-2xl"
      >
        {{ t('invite') }} {{ submitter.name }} <template v-if="!submitters.includes(submitter) && !isUnder16(submitter)">({{ t('optional') }})</template>
      </label>
      <p
        v-if="submitter.description"
        dir="auto"
        class="text-sm text-base-content/70 mb-2 whitespace-pre-line"
      >
        {{ submitter.description }}
      </p>
      <input
        :id="submitter.uuid"
        dir="auto"
        class="base-input !text-2xl w-full"
        :placeholder="t('email')"
        type="email"
        :required="submitters.includes(submitter) || isUnder16(submitter)"
        autofocus="true"
        name="submission[submitters][][email]"
      >
    </div>
    <div
      class="mt-4 md:mt-6"
    >
      <button
        type="submit"
        class="base-button w-full flex justify-center"
        :disabled="isSubmitting"
      >
        <span class="flex">
          <IconInnerShadowTop
            v-if="isSubmitting"
            class="mr-1 animate-spin"
          />
          <span>
            {{ t('complete') }}
          </span><span
            v-if="isSubmitting"
            class="w-6 flex justify-start mr-1"
          ><span>...</span></span>
        </span>
      </button>
    </div>
  </form>
</template>

<script>
import { IconInnerShadowTop } from '@tabler/icons-vue'

export default {
  name: 'InviteForm',
  components: {
    IconInnerShadowTop
  },
  inject: ['t'],
  props: {
    submitters: {
      type: Array,
      required: true
    },
    optionalSubmitters: {
      type: Array,
      required: false,
      default: () => []
    },
    url: {
      type: String,
      required: true
    },
    authenticityToken: {
      type: String,
      required: true
    },
    submitterSlug: {
      type: String,
      required: true
    },
    allFields: {
      type: Array,
      required: false,
      default: () => []
    },
    allSubmittersValues: {
      type: Object,
      required: false,
      default: () => ({})
    }
  },
  emits: ['success'],
  data () {
    return {
      isSubmitting: false
    }
  },
  computed: {
    birthDateFieldUuid () {
      // Find the birthdate field by looking for age_less_than conditions with value 16
      // in the fields of the optional invite submitters
      for (const submitter of this.optionalSubmitters) {
        const submitterFields = this.allFields.filter((f) => f.submitter_uuid === submitter.uuid)
        
        for (const field of submitterFields) {
          if (field.conditions && field.conditions.length) {
            for (const condition of field.conditions) {
              if (condition.action === 'age_less_than' && parseInt(condition.value, 10) === 16) {
                return condition.field_uuid
              }
            }
          }
        }
        
        // Also check if the submitter itself has conditions
        if (submitter.conditions && submitter.conditions.length) {
          for (const condition of submitter.conditions) {
            if (condition.action === 'age_less_than' && parseInt(condition.value, 10) === 16) {
              return condition.field_uuid
            }
          }
        }
      }
      
      return null
    }
  },
  methods: {
    calculateAge (dateString) {
      if (!dateString) {
        return null
      }

      try {
        const birthDate = new Date(dateString)
        if (isNaN(birthDate.getTime())) {
          return null
        }

        const today = new Date()
        let age = today.getFullYear() - birthDate.getFullYear()
        const monthDiff = today.getMonth() - birthDate.getMonth()

        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
          age--
        }

        return age
      } catch (e) {
        return null
      }
    },
    isUnder16 (submitter) {
      // Only check for optional submitters
      if (this.submitters.includes(submitter)) {
        return false
      }
      
      if (!this.birthDateFieldUuid) {
        return false
      }
      
      const birthDateValue = this.allSubmittersValues[this.birthDateFieldUuid]
      if (!birthDateValue) {
        return false
      }
      
      const age = this.calculateAge(birthDateValue)
      if (age === null) {
        return false
      }
      
      return age < 16
    },
    submit () {
      this.isSubmitting = true

      return fetch(this.url, {
        method: 'POST',
        body: new FormData(this.$refs.form)
      }).then((response) => {
        if (response.status === 200) {
          this.$emit('success')
        }
      }).finally(() => {
        this.isSubmitting = false
      })
    }
  }
}
</script>
