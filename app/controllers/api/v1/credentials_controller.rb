module Api
  module V1
    class CredentialsController < Api::BaseController
      before_action -> { require_permission!("credentials.read") }, only: %i[index show]
      before_action -> { require_permission!("credentials.write") }, only: %i[create]

      def index
        credentials = Current.organization.credentials.order(:name)
        render json: { credentials: credentials.map(&:to_public_hash) }
      end

      def show
        credential = Current.organization.credentials.find(params[:id])
        render json: { credential: credential.to_public_hash }
      end

      def create
        credential = Current.organization.credentials.new(credential_params.except(:secret))
        credential.secret = credential_params.fetch(:secret)
        credential.save!
        AuditLog.record!(
          organization: Current.organization,
          action: "credential.created",
          subject: credential,
          metadata: { kind: credential.kind },
          ip_address: request.remote_ip
        )

        render status: :created, json: { credential: credential.to_public_hash }
      end

      private

      def credential_params
        params.require(:credential).permit(:name, :kind, :secret, metadata_json: {})
      end
    end
  end
end
