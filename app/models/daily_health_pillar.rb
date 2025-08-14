# Join table model for Daily and HealthPillar relationship
class DailyHealthPillar < ApplicationRecord
  belongs_to :daily
  belongs_to :health_pillar

  validates :daily_id, presence: true
  validates :health_pillar_id, presence: true
  validates :daily_id, uniqueness: { scope: :health_pillar_id }
end
