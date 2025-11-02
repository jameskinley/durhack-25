export function corsHeaders(req?: Request): HeadersInit {
    // Echo requested headers if provided; otherwise allow common Supabase/browser headers
    const allowHeaders = req?.headers.get('Access-Control-Request-Headers')
        ?? 'Content-Type, Authorization, apikey, x-client-info';
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': allowHeaders,
        'Access-Control-Max-Age': '86400',
    };
}

export default function handleCorsPreflight(req: Request): Response {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
}