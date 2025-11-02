export function corsHeaders(req?: Request): HeadersInit {
    // Echo requested headers if provided; otherwise allow common Supabase/browser headers
    const allowHeaders = req?.headers.get('Access-Control-Request-Headers')
        ?? 'Content-Type, Authorization, apikey, x-client-info';
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': allowHeaders,
        'Access-Control-Max-Age': '86400',
        // Prevent intermediary and browser caching of function responses
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Surrogate-Control': 'no-store',
        // Ensure CORS varies correctly and avoids cached mismatches
        'Vary': 'Origin, Access-Control-Request-Headers',
    };
}

export default function handleCorsPreflight(req: Request): Response {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
}