# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Guardrails < Base
      def list(**params)
        conn.get("/guardrails", params: params)
      end

      def create(**body)
        conn.post("/guardrails", body: body, success: [201])
      end

      def get(id)
        conn.get("/guardrails/#{id}")
      end

      def update(id, **body)
        conn.patch("/guardrails/#{id}", body: body)
      end

      def delete(id)
        conn.delete("/guardrails/#{id}")
      end

      def list_key_assignments(guardrail_id, **params)
        conn.get("/guardrails/#{guardrail_id}/assignments/keys", params: params)
      end

      def bulk_assign_keys(guardrail_id, **body)
        conn.post("/guardrails/#{guardrail_id}/assignments/keys", body: body)
      end

      def bulk_unassign_keys(guardrail_id, **body)
        conn.post("/guardrails/#{guardrail_id}/assignments/keys/remove", body: body)
      end

      def list_member_assignments(guardrail_id, **params)
        conn.get("/guardrails/#{guardrail_id}/assignments/members", params: params)
      end

      def bulk_assign_members(guardrail_id, **body)
        conn.post("/guardrails/#{guardrail_id}/assignments/members", body: body)
      end

      def bulk_unassign_members(guardrail_id, **body)
        conn.post("/guardrails/#{guardrail_id}/assignments/members/remove", body: body)
      end

      def list_all_key_assignments(**params)
        conn.get("/guardrails/assignments/keys", params: params)
      end

      def list_all_member_assignments(**params)
        conn.get("/guardrails/assignments/members", params: params)
      end
    end
  end
end
