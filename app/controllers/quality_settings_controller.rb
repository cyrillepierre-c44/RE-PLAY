# Objectifs qualité (Bon du 1er coup VALO et TRI, délai avant le rouge) — admins.
class QualitySettingsController < ApplicationController
  def update
    authorize :page, :dashboard?
    setting = QualitySetting.current
    if setting.update(params.require(:quality_setting).permit(:target_valo, :target_tri, :red_after_days))
      redirect_back fallback_location: dashboard_path, notice: "Objectifs enregistrés.", status: :see_other
    else
      redirect_back fallback_location: dashboard_path, alert: setting.errors.full_messages.to_sentence, status: :see_other
    end
  end
end
