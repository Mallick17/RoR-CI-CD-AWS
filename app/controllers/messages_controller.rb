class MessagesController < ApplicationController
  def create
    @conversation = Conversation.includes(:receiver).find(params[:conversation_id])
    @message = @conversation.messages.create(message_params)
  end

  private

  def message_params
    params.require(:message).permit(:user_id, :body, :conversation_id)
  end
end