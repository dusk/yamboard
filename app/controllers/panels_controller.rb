class PanelsController < ApplicationController
  # GET /panels
  # GET /panels.xml
  def index
    @panels = Panel.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @panels }
    end
  end

  # GET /panels/1
  # GET /panels/1.xml
  def show
    @panel = Panel.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @panel }
    end
  end

  # GET /panels/new
  # GET /panels/new.xml
  def new
    @panel = Panel.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @panel }
    end
  end

  # GET /panels/1/edit
  def edit
    @panel = Panel.find(params[:id])
  end

  # POST /panels
  # POST /panels.xml
  def create
    @panel = Panel.new(params[:panel])

    respond_to do |format|
      if @panel.save
        format.html { redirect_to(@panel, :notice => 'Panel was successfully created.') }
        format.xml  { render :xml => @panel, :status => :created, :location => @panel }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @panel.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /panels/1
  # PUT /panels/1.xml
  def update
    @panel = Panel.find(params[:id])

    respond_to do |format|
      if @panel.update_attributes(params[:panel])
        format.html { redirect_to(@panel, :notice => 'Panel was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @panel.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /panels/1
  # DELETE /panels/1.xml
  def destroy
    @panel = Panel.find(params[:id])
    @panel.destroy

    respond_to do |format|
      format.html { redirect_to(panels_url) }
      format.xml  { head :ok }
    end
  end
end
