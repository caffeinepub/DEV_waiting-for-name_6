import MixinViews "mo:caffeineai-data-viewer/MixinViews";
import AccessControl "mo:caffeineai-authorization/access-control";
import MixinAuthorization "mo:caffeineai-authorization/MixinAuthorization";
import MixinCalendar "mixins/calendar-api";
import MixinOAuth "mixins/oauth-api";
import OAuthLib "lib/oauth";

actor {
  include MixinViews();

  let accessControlState : AccessControl.AccessControlState;
  include MixinAuthorization(accessControlState, null);

  let tokenStore : OAuthLib.TokenStore;
  include MixinOAuth(tokenStore);
  include MixinCalendar(tokenStore);
};
