module Api
  module V1
    class OrganizationsController < Api::BaseController
      skip_before_action :authenticate_api_key!, only: :create
      skip_before_action :enforce_rate_limit!, only: :create

      def create
        organization = nil
        issued_key = nil

        ActiveRecord::Base.transaction do
          organization = Organization.create!(organization_params)
          issued_key = FlowBridge::ApiKeyIssuer.issue!(
            organization: organization,
            name: params.dig(:api_key, :name).presence || "Owner API key",
            role: "owner"
          )
          Current.organization = organization
          AuditLog.record!(
            organization: organization,
            api_key: issued_key.api_key,
            action: "organization.created",
            subject: organization,
            metadata: { bootstrap: true },
            ip_address: request.remote_ip
          )
        end

        render status: :created, json: {
          organization: organization.to_public_hash,
          api_key: issued_key.api_key.to_public_hash.merge(token: issued_key.token)
        }
      end

      def show
        require_permission!("organization.read")
        organization = Current.organization
        raise ActiveRecord::RecordNotFound if organization.id != params[:id].to_i

        render json: { organization: organization.to_public_hash }
      end

      private

      def organization_params
        params.require(:organization).permit(:name, :slug, :plan, :rate_limit_per_minute)
      end
    end
  end
end
