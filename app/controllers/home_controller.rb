class HomeController < ApplicationController
  def index

    session[:conversations] ||= []
    if params[:search] && params[:search][:search_email].present?
      @users = User.where("email LIKE ? and id != ?", "%" + params[:search][:search_email] + "%" , current_user.id)
    else
      @users = User.all.where.not(id: current_user)
    end
    @conversations = Conversation.includes(:receiver, :messages).find(session[:conversations]).reverse_each
    puts session.to_hash
    puts @conversations
  end


end
