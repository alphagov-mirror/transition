class ImportBatchesController < ApplicationController
  include PaperTrail::Rails::Controller

  before_filter :find_site
  checks_user_can_edit
  before_filter :find_batch, only: [:preview, :import]

  def new
    @batch = ImportBatch.new
  end

  def create
    @batch = ImportBatch.new(batch_params)
    @batch.site = @site
    @batch.user = current_user
    if @batch.save
      redirect_to preview_site_import_batch_path(@site, @batch)
    else
      render 'new'
    end
  end

  def preview
    @preview = BatchPreviewPresenter.new(@batch)
  end

  def import
    if @batch.state == 'unqueued'
      @batch.update_attributes!(batch_params.merge(state: 'queued'))

      if @batch.entries_to_process.count > 20
        MappingsBatchWorker.perform_async(@batch.id)
        flash[:show_background_batch_progress_modal] = true
      else
        @batch.process
        @batch.update_column(:seen_outcome, true)

        outcome = BatchOutcomePresenter.new(@batch)
        flash[:saved_mapping_ids] = outcome.affected_mapping_ids
        flash[:success] = outcome.success_message
        flash[:saved_operation] = outcome.analytics_event_type
      end
    end

    redirect_to site_mappings_path(@site)
  end

protected
  def batch_params
    params.require(:import_batch).permit(:tag_list, :raw_csv, :update_existing)
  end

  def find_site
    @site = Site.find_by_abbr!(params[:site_id])
  end

  def find_batch
    @batch = @site.import_batches.find(params[:id])
  end
end