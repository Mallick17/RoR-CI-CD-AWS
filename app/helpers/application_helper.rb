module ApplicationHelper
  def search_email
    if params[:search].present?
      params[:search][:search_email]
    end
  end
end
