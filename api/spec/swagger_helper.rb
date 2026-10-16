# frozen_string_literal: true

require 'rails_helper'

# One source for the API contract: these schemas are used by the request specs (they fail if the API drifts)
# and are emitted into swagger/v1/swagger.yaml (served by Swagger UI at /api-docs in development).
# Regenerate with:  bundle exec rake rswag:specs:swaggerize
RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Assessment Platform API',
        version: 'v1',
        description: <<~DESC
          Multi-tenant API. The tenant is taken from the `scheme` claim of the JWT.
          Candidate-facing endpoints (`/sessions/{token}/...`) use the invite token instead of a JWT.
          Errors always have the shape `{ "errors": [ { "status": 422, "message": "..." } ] }`.
        DESC
      },
      servers: [{ url: 'http://localhost:3001', description: 'Local development' }],
      components: {
        securitySchemes: {
          bearer_auth: { type: :http, scheme: :bearer, bearerFormat: 'JWT' }
        },
        schemas: {
          Error: {
            type: :object,
            required: %w[errors],
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  required: %w[status message],
                  properties: { status: { type: :integer }, message: { type: :string } }
                }
              }
            }
          },
          Message: {
            type: :object, required: %w[message], properties: { message: { type: :string } }
          },
          PaginationMeta: {
            type: :object,
            required: %w[current_page total_pages total_count per_page],
            properties: {
              current_page: { type: :integer }, total_pages: { type: :integer },
              total_count: { type: :integer }, per_page: { type: :integer }
            }
          },
          SkillTaxonomy: {
            type: :object,
            required: %w[skill_id skill_label category l1_anchor l2_anchor l3_anchor l4_anchor l5_anchor],
            properties: {
              skill_id: { type: :string, example: 'SK-ENG-001' }, skill_label: { type: :string },
              category: { type: :string, enum: %w[engineering soft_skills product_process] },
              scope_include: { type: :string, nullable: true }, scope_exclude: { type: :string, nullable: true },
              l1_anchor: { type: :string }, l2_anchor: { type: :string }, l3_anchor: { type: :string },
              l4_anchor: { type: :string }, l5_anchor: { type: :string }
            }
          },
          AssessmentSkillInput: {
            type: :object,
            description: 'Nested attributes. To remove an existing skill send `{ id, _destroy: true }`; ' \
                         'skills that are merely omitted are NOT removed (audit R-03).',
            properties: {
              id: { type: :integer }, skill_id: { type: :string, nullable: true }, skill_label: { type: :string },
              is_custom: { type: :boolean }, scope_include: { type: :string }, scope_exclude: { type: :string },
              l1_anchor: { type: :string }, l2_anchor: { type: :string }, l3_anchor: { type: :string },
              l4_anchor: { type: :string }, l5_anchor: { type: :string },
              expected_level: { type: :integer, minimum: 1, maximum: 5 }, display_order: { type: :integer },
              _destroy: { type: :boolean }
            }
          },
          AssessmentInput: {
            type: :object,
            required: %w[name time_limit_min],
            properties: {
              name: { type: :string, example: 'Senior Backend Engineer' },
              time_limit_min: { type: :integer, enum: [10, 30, 45, 60, 90] },
              language: { type: :string, enum: %w[en id] },
              assessment_skills_attributes: { type: :array, items: { '$ref' => '#/components/schemas/AssessmentSkillInput' } }
            }
          },
          LatestSession: {
            type: :object, nullable: true,
            properties: { id: { type: :integer }, status: { type: :string }, end_reason: { type: :string, nullable: true } }
          },
          Assessment: {
            type: :object,
            required: %w[id name time_limit_min language created_by latest_session],
            properties: {
              id: { type: :integer }, name: { type: :string }, time_limit_min: { type: :integer },
              language: { type: :string }, system_prompt: { type: :string, nullable: true },
              created_by: { type: :integer }, created_at: { type: :string }, updated_at: { type: :string },
              latest_session: { '$ref' => '#/components/schemas/LatestSession' }
            }
          },
          AssessmentSkill: {
            type: :object,
            required: %w[id skill_label is_custom expected_level display_order l1_anchor l5_anchor],
            properties: {
              id: { type: :integer }, skill_id: { type: :string, nullable: true }, skill_label: { type: :string },
              is_custom: { type: :boolean }, scope_include: { type: :string, nullable: true },
              scope_exclude: { type: :string, nullable: true },
              l1_anchor: { type: :string }, l2_anchor: { type: :string }, l3_anchor: { type: :string },
              l4_anchor: { type: :string }, l5_anchor: { type: :string },
              expected_level: { type: :integer, nullable: true }, display_order: { type: :integer }
            }
          },
          AssessmentWithSkills: {
            allOf: [
              { '$ref' => '#/components/schemas/Assessment' },
              {
                type: :object, required: %w[skills],
                properties: { skills: { type: :array, items: { '$ref' => '#/components/schemas/AssessmentSkill' } } }
              }
            ]
          },
          Session: {
            type: :object,
            required: %w[id assessment_id tenant_id invite_token invite_url status],
            properties: {
              id: { type: :integer }, assessment_id: { type: :integer }, tenant_id: { type: :integer },
              candidate_id: { type: :integer, nullable: true }, candidate_name: { type: :string, nullable: true },
              invite_token: { type: :string },
              invite_url: { type: :string, description: 'Built from APP_BASE_URL, which currently is the API host (audit R-07).' },
              status: { type: :string, enum: %w[pending active ended failed] },
              end_reason: { type: :string, nullable: true,
                            enum: ['manual_candidate', 'manual_assessor', 'all_covered', 'time_ceiling', 'error', nil] },
              started_at: { type: :string, nullable: true }, ended_at: { type: :string, nullable: true },
              duration_seconds: { type: :integer, nullable: true }, created_at: { type: :string }
            }
          },
          CoverageSkill: {
            type: :object,
            required: %w[id skill_label is_discovered state probe_count],
            properties: {
              id: { type: :integer }, skill_id: { type: :string, nullable: true }, skill_label: { type: :string },
              is_discovered: { type: :boolean },
              state: { type: :string, enum: %w[not_yet initiated partial covered] },
              probe_count: { type: :integer }, last_signal: { type: :string, nullable: true },
              updated_at: { type: :string }
            }
          },
          TranscriptTurn: {
            type: :object,
            required: %w[id turn_number speaker text],
            properties: {
              id: { type: :integer }, turn_number: { type: :integer },
              speaker: { type: :string, enum: %w[ai candidate] }, text: { type: :string },
              audio_start_ms: { type: :integer, nullable: true }, audio_end_ms: { type: :integer, nullable: true },
              created_at: { type: :string }
            }
          },
          PortfolioSkill: {
            type: :object,
            required: %w[id skill_label is_discovered ai_level ai_confidence evidence competency_summary],
            properties: {
              id: { type: :integer }, skill_id: { type: :string, nullable: true }, skill_label: { type: :string },
              is_discovered: { type: :boolean },
              ai_level: { type: :integer, minimum: 1, maximum: 5, description: 'Integer. (The web type declares it as a string.)' },
              ai_confidence: { type: :string, enum: %w[high medium low] },
              evidence: { type: :array, items: { type: :string } }, competency_summary: { type: :string }
            }
          },
          Override: {
            type: :object,
            required: %w[id portfolio_skill_id ai_level override_level overridden_by],
            properties: {
              id: { type: :integer }, portfolio_skill_id: { type: :integer },
              ai_level: { type: :integer }, override_level: { type: :integer, minimum: 1, maximum: 5 },
              assessor_notes: { type: :string, nullable: true }, overridden_by: { type: :integer },
              overridden_at: { type: :string }
            }
          },
          Portfolio: {
            type: :object,
            required: %w[id session_id generation_status skills overrides],
            properties: {
              id: { type: :integer }, session_id: { type: :integer }, candidate_id: { type: :integer, nullable: true },
              generation_status: { type: :string, enum: %w[pending generating complete failed] },
              generated_at: { type: :string, nullable: true }, generation_error: { type: :string, nullable: true },
              skills: { type: :array, items: { '$ref' => '#/components/schemas/PortfolioSkill' } },
              overrides: { type: :array, items: { '$ref' => '#/components/schemas/Override' } }
            }
          },
          SkillComparison: {
            type: :object,
            description: 'One row of the fit/gap table. The required level is `expected_level`; the web reads ' \
                         '`required_level` (audit R-08). `is_override` is not sent.',
            required: %w[skill_label expected_level result],
            properties: {
              skill_label: { type: :string }, skill_id: { type: :string, nullable: true },
              expected_level: { type: :integer }, candidate_level: { type: :integer, nullable: true },
              result: { type: :string, enum: %w[match gap exceed not_assessed] },
              delta: { type: :integer, nullable: true }, confidence: { type: :string, nullable: true }
            }
          },
          FitGapReport: {
            type: :object,
            required: %w[id portfolio_id vacancy_id skill_comparisons],
            properties: {
              id: { type: :integer }, portfolio_id: { type: :integer }, vacancy_id: { type: :integer },
              skill_comparisons: { type: :array, items: { '$ref' => '#/components/schemas/SkillComparison' } },
              culture_narrative: { type: :string, nullable: true }, overall_narrative: { type: :string, nullable: true },
              generated_at: { type: :string }
            }
          },
          VacancySkillInput: {
            type: :object,
            description: 'Nested attributes. To remove an existing skill send `{ id, _destroy: true }`.',
            properties: {
              id: { type: :integer }, skill_id: { type: :string, nullable: true }, skill_label: { type: :string },
              expected_level: { type: :integer, minimum: 1, maximum: 5 }, _destroy: { type: :boolean }
            }
          },
          VacancyInput: {
            type: :object,
            required: %w[role_title],
            properties: {
              role_title: { type: :string }, culture_dimensions: { type: :string }, competency_expectations: { type: :string },
              vacancy_skills_attributes: { type: :array, items: { '$ref' => '#/components/schemas/VacancySkillInput' } }
            }
          },
          Vacancy: {
            type: :object,
            required: %w[id role_title created_by],
            properties: {
              id: { type: :integer }, role_title: { type: :string },
              culture_dimensions: { type: :string, nullable: true }, competency_expectations: { type: :string, nullable: true },
              created_by: { type: :integer }, created_at: { type: :string }, updated_at: { type: :string }
            }
          },
          VacancySkill: {
            type: :object,
            required: %w[id skill_label expected_level],
            properties: {
              id: { type: :integer }, skill_id: { type: :string, nullable: true }, skill_label: { type: :string },
              expected_level: { type: :integer }, l1_anchor: { type: :string, nullable: true },
              l2_anchor: { type: :string, nullable: true }, l3_anchor: { type: :string, nullable: true },
              l4_anchor: { type: :string, nullable: true }, l5_anchor: { type: :string, nullable: true }
            }
          },
          VacancyWithSkills: {
            allOf: [
              { '$ref' => '#/components/schemas/Vacancy' },
              {
                type: :object, required: %w[skills],
                properties: { skills: { type: :array, items: { '$ref' => '#/components/schemas/VacancySkill' } } }
              }
            ]
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
