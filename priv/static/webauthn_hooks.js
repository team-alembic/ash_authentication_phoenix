// SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
//
// SPDX-License-Identifier: MIT

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
 *
 * The server pushes spec-shaped PublicKeyCredentialCreationOptions /
 * PublicKeyCredentialRequestOptions (the same JSON the strategy's Plug
 * endpoints return). Binary fields are base64url without padding in both
 * directions. Options are passed through generically so server-added keys
 * (e.g. future extensions) survive without changes here.
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

// Decode a list of PublicKeyCredentialDescriptor entries, keeping any
// extra keys (e.g. transports) intact. `id` arrives base64url-encoded.
function decodeCredentialDescriptors(descriptors) {
  return (descriptors || []).map((cred) => ({
    ...cred,
    id: base64UrlToArray(cred.id),
    type: cred.type || "public-key",
  }));
}

// The server JSON-encodes the authenticator attachment atom with an
// underscore, but the WebAuthn API expects a hyphen.
function normalizeAuthenticatorSelection(selection) {
  const normalized = { ...(selection || {}) };

  for (const key of Object.keys(normalized)) {
    if (normalized[key] == null) delete normalized[key];
  }

  if (normalized.authenticatorAttachment === "cross_platform") {
    normalized.authenticatorAttachment = "cross-platform";
  }

  // Back-compat for authenticators that predate residentKey.
  if (normalized.residentKey === "required") {
    normalized.requireResidentKey = true;
  }

  return normalized;
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

    this.pushEventTo(this.el, "passkeys-supported", { supported });

    if (supported && window.PublicKeyCredential.isConditionalMediationAvailable) {
      window.PublicKeyCredential.isConditionalMediationAvailable().then(
        (available) => {
          this.pushEventTo(this.el, "conditional-ui-available", { available });
        }
      );
    }
  },
};

/**
 * WebAuthnRegistrationHook
 *
 * Handles the registration ceremony.
 * Listens for "registration-challenge" event from server (spec-shaped
 * creation options), calls navigator.credentials.create(), pushes
 * "registration-attestation" back — including the credential's transports
 * and client extension results, which only the client can report.
 */
export const WebAuthnRegistrationHook = {
  mounted() {
    this.handleEvent("registration-challenge", (data) => {
      this.handleRegistration(data);
    });
  },

  async handleRegistration(data) {
    try {
      // Use the server's options verbatim (decoding binary fields) so
      // server-added keys pass through untouched. In particular the
      // server's user.id is the canonical user handle — it is persisted
      // with the credential, so it must not be synthesized client-side.
      const publicKeyOptions = {
        ...data,
        challenge: base64UrlToArray(data.challenge),
        user: {
          ...data.user,
          id: base64UrlToArray(data.user.id),
        },
        excludeCredentials: decodeCredentialDescriptors(data.excludeCredentials),
        authenticatorSelection: normalizeAuthenticatorSelection(
          data.authenticatorSelection
        ),
        timeout: data.timeout || 60000,
        attestation: data.attestation || "none",
      };

      const credential = await navigator.credentials.create({
        publicKey: publicKeyOptions,
      });

      if (!credential) {
        this.pushEventTo(this.el, "registration-error", {
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

      const transports =
        typeof response.getTransports === "function"
          ? response.getTransports()
          : [];

      const clientExtensionResults =
        typeof credential.getClientExtensionResults === "function"
          ? credential.getClientExtensionResults()
          : {};

      this.pushEventTo(this.el, "registration-attestation", {
        attestation_object: attestationObject,
        client_data_json: clientDataJSON,
        raw_id: rawId,
        transports: transports,
        // Today only credProps is consumed server-side; sending the whole
        // object is forward-compatible with future extensions.
        cred_props: clientExtensionResults.credProps || null,
        client_extension_results: clientExtensionResults,
      });
    } catch (error) {
      this.pushEventTo(this.el, "registration-error", {
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
 * Listens for "authentication-challenge" event from server (spec-shaped
 * request options), calls navigator.credentials.get(), pushes
 * "authentication-assertion" back.
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
        ...data,
        challenge: base64UrlToArray(data.challenge),
        timeout: data.timeout || 60000,
        userVerification: data.userVerification || "preferred",
      };

      if (data.allowCredentials && data.allowCredentials.length > 0) {
        // Entries may carry a transports hint captured at registration —
        // decode the id, keep everything else as-is.
        publicKeyOptions.allowCredentials = decodeCredentialDescriptors(
          data.allowCredentials
        );
      } else {
        delete publicKeyOptions.allowCredentials;
      }

      const credential = await navigator.credentials.get({
        publicKey: publicKeyOptions,
        mediation: mediation,
      });

      if (!credential) {
        this.pushEventTo(this.el, "authentication-error", {
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

      this.pushEventTo(this.el, "authentication-assertion", {
        raw_id: rawId,
        authenticator_data: authenticatorData,
        signature: signature,
        client_data_json: clientDataJSON,
        user_handle: userHandle,
      });
    } catch (error) {
      this.pushEventTo(this.el, "authentication-error", {
        message: error.message,
        name: error.name,
      });
    }
  },
};
