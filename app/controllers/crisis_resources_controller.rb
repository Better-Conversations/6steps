# frozen_string_literal: true

class CrisisResourcesController < ApplicationController
  before_action :authenticate_user!

  def show
    @region = current_user.region
    @resources = CrisisResources.for_region(@region.to_sym)
    @grounding_exercises = CrisisResources.all_grounding_exercises
  end
end
