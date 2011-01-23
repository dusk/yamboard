class WidgetsController < ApplicationController

  respond_to :js, :xml, :html

  # GET /widgets
  # GET /widgets.xml
  def index
    respond_with(@widgets = Widget.all)
  end

  # GET /widgets/1
  # GET /widgets/1.xml
  def show
    respond_with(@widget = Widget.find(params[:id]))
  end

  # GET /widgets/new
  # GET /widgets/new.xml
  def new
    respond_with(@widget = Widget.new)
  end

  # GET /widgets/1/edit
  def edit
    respond_with(@widget = Widget.find(params[:id]))
  end

  # POST /widgets
  # POST /widgets.xml
  def create
    @widget = Widget.new(params[:widget])

    if @widget.save
      respond_with(@widget)
    else
      respond_with(@widget.errors, :location => root_path)
    end
  end

  # PUT /widgets/1
  # PUT /widgets/1.xml
  def update
    @widget = Widget.find(params[:id])

    if @widget.update_attributes(params[:widget])
      respond_with @widget
    else
      respond_with(@widget.errors, :location => root_path)
    end
  end

  # DELETE /widgets/1
  # DELETE /widgets/1.xml
  def destroy
    @widget = Widget.find(params[:id])
    @widget.destroy

    respond_to do |format|
      format.html { redirect_to(root_path) }
      format.xml  { head :ok }
      format.js   { render :nothing => true }
    end
  end
end
