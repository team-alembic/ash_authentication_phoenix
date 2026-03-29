/**
 * WebAuthn hooks for AshAuthentication Phoenix.
 *
 * Usage in your app.js:
 *
 *   import {
 *     WebAuthnRegistrationHook,
 *     WebAuthnAuthenticationHook,
 *     WebAuthnSupportHook
 *   } from "../../deps/ash_authentication_phoenix/priv/static/webauthn_hooks";
 *
 *   let liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: {
 *       ...WebAuthnRegistrationHook,
 *       ...WebAuthnAuthenticationHook,
 *       ...WebAuthnSupportHook,
 *       // your other hooks...
 *     }
 *   });
 */

// Utility: base64url string to Uint8Array
function base64UrlToArray(base64url) {
  if (typeof base64url !== 'string' || base64url.length === 0) {
    throw new TypeError('Expected non-empty base64url string, got ' + typeof base64url);
  }
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(base64 + padding);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Utility: ArrayBuffer to base64url string
function arrayBufferToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * WebAuthnSupportHook
 *
 * Detects whether the browser supports WebAuthn.
 * Attach to a hidden element. Pushes "passkeys-supported" event.
 */
export const WebAuthnSupportHook = {
  mounted() {
    const supported =
      typeof window !== "undefined" &&
      typeof window.PublicKeyCredential !== "undefined";

    this.pushEvent("passkeys-supported", { supported });

    if (supported && window.PublicKeyCredential.isConditionalMediationAvailable) {
      window.PublicKeyCredential.isConditionalMediationAvailable().then(
        (available) => {
          this.pushEvent("conditional-ui-available", { available });
        }
      );
    }
  },
};

/**
 * WebAuthnRegistrationHook
 *
 * Handles the registration ceremony.
 * Listens for "registration-challenge" event from server,
 * calls navigator.credentials.create(), pushes "registration-attestation" back.
 */
export const WebAuthnRegistrationHook = {
  mounted() {
    this.handleEvent("registration-challenge", (data) => {
      this.handleRegistration(data);
    });
  },

  async handleRegistration(data) {
    try {
      const publicKeyOptions = {
        challenge: base64UrlToArray(data.challenge),
        rp: {
          id: data.rp_id,
          name: data.rp_name,
        },
        user: {
          id: base64UrlToArray(data.user_id),
          name: data.user_name,
          displayName: data.user_display_name || data.user_name,
        },
        pubKeyCredParams: [
          { alg: -7, type: "public-key" },  // ES256
          { alg: -257, type: "public-key" }, // RS256
        ],
        timeout: data.timeout || 60000,
        attestation: data.attestation || "none",
        authenticatorSelection: {},
      };

      if (data.authenticator_attachment) {
        publicKeyOptions.authenticatorSelection.authenticatorAttachment =
          data.authenticator_attachment === "cross_platform"
            ? "cross-platform"
            : data.authenticator_attachment;
      }

      if (data.user_verification) {
        publicKeyOptions.authenticatorSelection.userVerification =
          data.user_verification;
      }

      if (data.resident_key) {
        publicKeyOptions.authenticatorSelection.residentKey = data.resident_key;
        if (data.resident_key === "required") {
          publicKeyOptions.authenticatorSelection.requireResidentKey = true;
        }
      }

      if (data.exclude_credentials) {
        publicKeyOptions.excludeCredentials = data.exclude_credentials.map(
          (cred) => ({
            id: base64UrlToArray(cred.id),
            type: "public-key",
          })
        );
      }

      const credential = await navigator.credentials.create({
        publicKey: publicKeyOptions,
      });

      if (!credential) {
        this.pushEvent("registration-error", {
          message: "No credential was returned by the browser.",
          name: "NullCredential",
        });
        return;
      }

      const response = credential.response;
      const attestationObject = arrayBufferToBase64Url(
        response.attestationObject
      );
      const clientDataJSON = arrayBufferToBase64Url(response.clientDataJSON);
      const rawId = arrayBufferToBase64Url(credential.rawId);

      this.pushEvent("registration-attestation", {
        attestation_object: attestationObject,
        client_data_json: clientDataJSON,
        raw_id: rawId,
      });
    } catch (error) {
      this.pushEvent("registration-error", {
        message: error.message,
        name: error.name,
      });
    }
  },
};

/**
 * WebAuthnAuthenticationHook
 *
 * Handles the authentication ceremony.
 * Listens for "authentication-challenge" event from server,
 * calls navigator.credentials.get(), pushes "authentication-assertion" back.
 */
export const WebAuthnAuthenticationHook = {
  mounted() {
    this.handleEvent("authentication-challenge", (data) => {
      this.handleAuthentication(data, "optional");
    });

    this.handleEvent("authentication-challenge-conditional", (data) => {
      this.handleAuthentication(data, "conditional");
    });
  },

  async handleAuthentication(data, mediation) {
    try {
      const publicKeyOptions = {
        challenge: base64UrlToArray(data.challenge),
        rpId: data.rp_id,
        timeout: data.timeout || 60000,
        userVerification: data.user_verification || "preferred",
      };

      if (data.allow_credentials && data.allow_credentials.length > 0) {
        publicKeyOptions.allowCredentials = data.allow_credentials.map(
          (cred) => ({
            id: base64UrlToArray(cred.id),
            type: "public-key",
          })
        );
      }

      const credential = await navigator.credentials.get({
        publicKey: publicKeyOptions,
        mediation: mediation,
      });

      if (!credential) {
        this.pushEvent("authentication-error", {
          message: "No credential was returned by the browser.",
          name: "NullCredential",
        });
        return;
      }

      const response = credential.response;
      const rawId = arrayBufferToBase64Url(credential.rawId);
      const authenticatorData = arrayBufferToBase64Url(
        response.authenticatorData
      );
      const signature = arrayBufferToBase64Url(response.signature);
      const clientDataJSON = arrayBufferToBase64Url(response.clientDataJSON);
      const userHandle = response.userHandle
        ? arrayBufferToBase64Url(response.userHandle)
        : null;

      this.pushEvent("authentication-assertion", {
        raw_id: rawId,
        authenticator_data: authenticatorData,
        signature: signature,
        client_data_json: clientDataJSON,
        user_handle: userHandle,
      });
    } catch (error) {
      this.pushEvent("authentication-error", {
        message: error.message,
        name: error.name,
      });
    }
  },
};
