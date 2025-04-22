class Message < ApplicationRecord
  belongs_to :user
  belongs_to :conversation
  validates :body, presence: :true
  after_create_commit { MessageBroadcastJob.perform_later(self) }
end
