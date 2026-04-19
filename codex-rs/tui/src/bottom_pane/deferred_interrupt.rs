use codex_features::Features;
use codex_protocol::request_user_input::RequestUserInputEvent;

use crate::app::app_server_requests::ResolvedAppServerRequest;
use crate::bottom_pane::ApprovalRequest;
use crate::bottom_pane::McpServerElicitationFormRequest;

#[derive(Clone)]
pub(crate) enum DeferredInterruptRequest {
    Approval {
        request: ApprovalRequest,
        features: Features,
    },
    UserInput {
        request: RequestUserInputEvent,
    },
    McpElicitation {
        request: McpServerElicitationFormRequest,
    },
}

impl DeferredInterruptRequest {
    pub(crate) fn matches_resolved_request(&self, request: &ResolvedAppServerRequest) -> bool {
        match self {
            DeferredInterruptRequest::Approval {
                request: approval, ..
            } => approval.matches_resolved_request(request),
            DeferredInterruptRequest::UserInput {
                request: user_input,
            } => {
                matches!(request, ResolvedAppServerRequest::UserInput { call_id } if user_input.call_id == *call_id)
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
