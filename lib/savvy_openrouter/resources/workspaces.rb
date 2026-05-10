# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Workspaces < Base
      def list(**params)
        conn.get("/workspaces", params: params)
      end

      def create(**body)
        conn.post("/workspaces", body: body, success: [201])
      end

      def get(id)
        conn.get("/workspaces/#{id}")
      end

      def update(id, **body)
        conn.patch("/workspaces/#{id}", body: body)
      end

      def delete(id)
        conn.delete("/workspaces/#{id}")
      end

      def bulk_add_members(workspace_id, **body)
        conn.post("/workspaces/#{workspace_id}/members/add", body: body)
      end

      def bulk_remove_members(workspace_id, **body)
        conn.post("/workspaces/#{workspace_id}/members/remove", body: body)
      end
    end
  end
end
