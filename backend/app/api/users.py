from fastapi import APIRouter, Depends
from app.api.deps import get_current_user, get_user_repo
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.user import UserRead, UserUpdate
from app.repositories.user_repository import UserRepository

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=ApiResponse[UserRead])
async def get_my_profile(current_user: User = Depends(get_current_user)):
    """Fetch profile of current authenticated commuter."""
    return ApiResponse(
        success=True,
        data=UserRead.model_validate(current_user),
    )


@router.put("/me", response_model=ApiResponse[UserRead])
async def update_my_profile(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    user_repo: UserRepository = Depends(get_user_repo),
):
    """Update profile metadata (name, email, profile photo)."""
    updated = await user_repo.update_profile(
        user_id=current_user.id,
        full_name=payload.full_name,
        email=str(payload.email) if payload.email else None,
        profile_image_url=payload.profile_image_url,
    )
    return ApiResponse(
        success=True,
        message="Profile updated successfully.",
        data=UserRead.model_validate(updated),
    )
