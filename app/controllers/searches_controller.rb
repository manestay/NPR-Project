class SearchesController < ApplicationController
  before_action :set_search, only: [:show, :update, :destroy, :download]
  include SearchesHelper

  def index
    return unless current_user
    @searches = current_user.searches
  end

  def new
    @search = Search.new
  end

  def create
    @search = Search.new(search_params)

    current_user.searches << @search if current_user

    @transcripts = Transcript.order_by(:date.desc).where(
      :date.gte => @search.start_date,
      :date.lte => @search.end_date
    )

    searcher = SearchDatabase.new

    @hits = searcher.search(
      @search.phrase,
      transcripts: @transcripts,
      limit: @search.limit,
      use_regex: @search.regex,
      sort_by: @search.sort_by
    )

    save_search(@transcripts.count)

    redirect_to search_path(id: @search.id)
  end

  def show
    @results = @search.results.page(params[:page])
  end

  def download
    phrase = @search.phrase
    time = @search.submitted_at
    file_location = generate_csv(@search.results, phrase, time)
    send_file(file_location, type: 'text/csv', disposition: 'attachment')
  end

  def destroy
    @search.results.destroy_all
    @search.destroy
    respond_to do |format|
      format.html do
        redirect_to history_path, notice: 'Search was successfully destroyed.'
      end
      format.json { head :no_content }
    end
  end

  private

  def set_search
    @search = Search.find(params[:id])
  end

  def save_search(transcript_count)
    @search.update_attribute(:transcript_count, transcript_count)
    @hits.each do |hit|
      @search.results << hit
      hit.save
    end
    @search.save
  end

  def search_params
    params.require(:search).permit(
      :phrase,
      :limit,
      :start_date,
      :end_date,
      :submitted_at,
      :regex,
      :sort_by
    )
  end
end
