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
 *   } from "ash_authentication_phoenix/priv/static/webauthn_hooks.js";
 *
 *   let liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: {
 *       WebAuthnRegistrationHook,
 *       WebAuthnAuthenticationHook,
 *       WebAuthnSupportHook,
 *       // your other hooks...
 *     }
 *   });
 *
 * The server pushes spec-shaped PublicKeyCredentialCreationOptions /
 * PublicKeyCredentialRequestOptions (the same JSON the strategy's Plug
 * endpoints return). Binary fields are base64url without padding in both
 * directions. Options are passed through to the browser as the server sent
 * them — `timeout`, `hints`, `userVerification`, `attestation` and any key
 * added later all survive without changes here, and nothing is defaulted
 * client-side: the strategy's configuration is the one source of truth.
 *
 * A pushed event reaches every hook on the page that listens for it, so the
 * server addresses each one to a hook element with `target` (its DOM id).
 * A hook ignores options meant for another element, and `target` is removed
 * before the options reach the browser.
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

// `authenticatorSelection` as the browser takes it: no null members (the
// absence of a key is how "no preference" is spelled), the hyphenated
// attachment enum should a server ever send the snake-case atom, and the
// Level 1 `requireResidentKey` for clients predating `residentKey`.
function normalizeAuthenticatorSelection(selection) {
  const normalized = { ...(selection || {}) };

  for (const key of Object.keys(normalized)) {
    if (normalized[key] == null) delete normalized[key];
  }

  if (normalized.authenticatorAttachment === "cross_platform") {
    normalized.authenticatorAttachment = "cross-platform";
  }

  if (normalized.residentKey === "required") {
    normalized.requireResidentKey = true;
  }

  return normalized;
}

// Whether pushed options are meant for this hook's element. Options without
// a `target` are taken by every hook, as they were before targeting existed.
function addressedTo(el, data) {
  return !data || data.target == null || data.target === el.id;
}

// The options without the delivery address.
function withoutTarget(data) {
  const { target, ...options } = data;
  return options;
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
      if (addressedTo(this.el, data)) this.handleRegistration(withoutTarget(data));
    });
  },

  async handleRegistration(data) {
    try {
      // The server's options verbatim, with the binary fields decoded, so
      // server-added keys pass through untouched. In particular the
      // server's user.id is the canonical user handle — it is persisted
      // with the credential, so it must not be synthesized client-side —
      // and `timeout` and `hints` are the strategy's own.
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
      if (addressedTo(this.el, data)) {
        this.handleAuthentication(withoutTarget(data), "optional");
      }
    });

    this.handleEvent("authentication-challenge-conditional", (data) => {
      if (addressedTo(this.el, data)) {
        this.handleAuthentication(withoutTarget(data), "conditional");
      }
    });
  },

  async handleAuthentication(data, mediation) {
    try {
      // The server's options verbatim, with the challenge decoded; `timeout`,
      // `hints` and `userVerification` are the strategy's own.
      const publicKeyOptions = {
        ...data,
        challenge: base64UrlToArray(data.challenge),
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
