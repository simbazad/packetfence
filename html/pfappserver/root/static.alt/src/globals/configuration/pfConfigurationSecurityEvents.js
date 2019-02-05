import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormSecurityEventTrigger from '@/components/pfFormSecurityEventTrigger'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional
} from '@/globals/pfValidators'

const {
  numeric,
  required,
  alphaNum,
  maxLength,
  minValue,
  maxValue
} = require('vuelidate/lib/validators')

export const pfConfigurationSecurityEventsListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Identifier') }), // re-label
  pfConfigurationListColumns.desc
]

export const pfConfigurationSecurityEventViewDefaults = (context = {}) => {
  return {
    id: null,
    priority: 4,
  }
}

export const pfConfigurationSecurityEventsListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Identifer') }), // re-text
  pfConfigurationListFields.desc
]

export const pfConfigurationSecurityEventViewFields = (context = {}) => {
  const {
      isNew = false,
      isClone = false,
      roles = []
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Identifier'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name required.')]: required,
                [i18n.t('Numeric value required.')]: numeric
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'desc',
              component: pfFormInput,
              validators: {
                [i18n.t('Description required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('Priority'),
          fields: [
            {
              key: 'priority',
              component: pfFormInput,
              validators: {
                [i18n.t('Priority required')]: required,
                [i18n.t('Value must be numeric.')]: numeric,
                [i18n.t('Value must be at least 1')]: minValue(1),
                [i18n.t('Value must be maximum 10')]: maxValue(10)
              }
            }
          ]
        },
        {
          label: i18n.t('Ignored Roles'),
          fields: [
            {
              key: 'whitelisted_roles',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to select a role'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: roles.map(role => { return { value: role.name, text: role.name } })
              }
            }
          ]
        },
        {
          label: i18n.t('Event triggers'),
          fields: [
            {
              key: 'trigger',
              component: pfFormSecurityEventTrigger,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Event triggers'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: ["device::2", "device::3"].map(trigger => { return { value: trigger, text: trigger } })
              }
            }
          ]
        },
      ],
    }
  ]
}

export const pfConfigurationSecurityEventListConfig = (context = {}) => {
  return {
    columns: pfConfigurationSecurityEventsListColumns,
    fields: pfConfigurationSecurityEventsListFields,
    rowClickRoute (item, index) {
      return { name: 'security_event', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name'),
    searchableOptions: {
      //TODO: change once we rename API
      searchApiEndpoint: 'config/violations',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'desc', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'security_events' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}
