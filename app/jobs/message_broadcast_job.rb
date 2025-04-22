class MessageBroadcastJob < ApplicationJob
  def perform(message)
    sender = message.user
    receiver = message.conversation.opposed_user(sender)

    broadcast_to_sender(sender, message)
    broadcast_to_receiver(receiver, message)
  end

  private

  def broadcast_to_sender(user, message)
    ActionCable.server.broadcast(
      "conversations-#{user.id}",
      {title:"job bs",
       message: render_message(message, user),
      conversation_id: message.conversation_id}
    )
  end

  def broadcast_to_receiver(user, message)
    ActionCable.server.broadcast(
      "conversations-#{user.id}",
      {title:"job br",
      message: render_message(message, user),
      conversation_id: message.conversation_id}
    )
  end
  def render_message(message, user)
    ApplicationController.render(
      partial: 'messages/message',
      locals: { message: message, user: user }
    )
  end
end
