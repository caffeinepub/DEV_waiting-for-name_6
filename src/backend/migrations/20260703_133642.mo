import Map "mo:core/Map";
import Principal "mo:core/Principal";

module {
  type UserRole = {
    #admin;
    #user;
    #guest;
  };

  type AccessControlState = {
    var adminAssigned : Bool;
    userRoles : Map.Map<Principal, UserRole>;
  };

  type StoredTokens = {
    accessToken : Text;
    refreshToken : ?Text;
    expiresIn : Nat;
    storedAt : Int;
  };

  // Init migration: this is the first file in the chain, so OldActor is empty
  // and NewActor must supply initial values for every stable field declared
  // in main.mo (accessControlState and tokenStore). Initializers are inlined
  // here because the actor body has no initializers under enhanced migration.
  type OldActor = {};

  type NewActor = {
    accessControlState : AccessControlState;
    tokenStore : Map.Map<Principal, StoredTokens>;
  };

  public func migration(old : OldActor) : NewActor {
    {
      accessControlState = {
        var adminAssigned = false;
        userRoles = Map.empty();
      };
      tokenStore = Map.empty();
    };
  };
};
