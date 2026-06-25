'use strict';

/**
 * Configuracion PUBLICA del frontend de Hotel Nyx.
 *
 * ⚠️ SEGURIDAD: aqui SOLO van valores publicos. NUNCA pongas access tokens,
 * client secrets, la password de la BD ni la PRIVATE/ACCESS KEY de Mercado Pago.
 * Todos esos secretos viven en AWS Secrets Manager y los usa el backend.
 *
 * Reemplaza los placesholders REEMPLAZAR_* con los valores reales (salen de los
 * outputs de Terraform en iac/dev/):
 *   - API_BASE_URL          → output `api_custom_domain_url` (o `api_gateway_endpoint`)
 *   - COGNITO_HOSTED_UI     → output `cognito_hosted_ui_url`
 *   - COGNITO_USER_POOL_ID  → output `cognito_user_pool_id`
 *   - COGNITO_CLIENT_ID     → output `cognito_client_id`
 *   - MP_PUBLIC_KEY         → Public Key de TEST de Mercado Pago (es publica)
 *
 * REDIRECT_URI y LOGOUT_URI deben estar dados de alta en el app client de
 * Cognito (variables cognito_callback_urls / cognito_logout_urls del IaC).
 */
window.HOTEL_NYX_CONFIG = {
  // URL base del API Gateway (sin slash final).
  API_BASE_URL:    "https://2suddte9da.execute-api.us-east-2.amazonaws.com",

  // Hosted UI de Cognito.
  COGNITO_HOSTED_UI: 'https://hotel-nyx-dev.auth.us-east-2.amazoncognito.com',
  COGNITO_USER_POOL_ID: 'us-east-2_mpOHhcfwB',
  COGNITO_CLIENT_ID: '6mvsog8sjk8k7rssvv8tpliiai',

  COGNITO_SCOPES: 'openid email profile hotel-api/guest:reserve hotel-api/admin:write',

  REDIRECT_URI: window.location.origin + '/login.html',
  LOGOUT_URI: window.location.origin + '/index.html',

  // Pega aquí TU Public Key TEST de Mercado Pago (empieza con TEST- o APP_USR-)
  MP_PUBLIC_KEY: 'APP_USR-d91be1c3-9fe7-4cd4-9564-1c4215709da5',

  ADMIN_SCOPE: 'hotel-api/admin:write',
};
