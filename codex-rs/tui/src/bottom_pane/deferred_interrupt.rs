use codex_app_server_protocol::ToolRequestUserInputParams;

use crate::app::app_server_requests::ResolvedAppServerRequest;
use crate::bottom_pane::McpServerElicitationFormRequest;

#[derive(Clone)]
pub(crate) enum DeferredInterruptRequest {
    UserInput {
        request: ToolRequestUserInputParams,
    },
    McpElicitation {
        request: McpServerElicitationFormRequest,
    },
}

impl DeferredInterruptRequest {
    pub(crate) fn matches_resolved_request(&self, request: &ResolvedAppServerRequest) -> bool {
        match self {
            DeferredInterruptRequest::UserInput {
                request: user_input,
            } => {
                matches!(request, ResolvedAppServerRequest::UserInput { call_id } if user_input.item_id == *call_id)
            }
            DeferredInterruptRequest::McpElicitation {
                request: elicitation,
            } => {
                matches!(
                    request,
                    ResolvedAppServerRequest::McpElicitation {
                        server_name,
                        request_id,
                    } if elicitation.server_name() == server_name && elicitation.request_id() == request_id
                )
            }
        }
    }
}
