export default function handleCorsPreflight(req: Request): Response {
    const headers = new Headers();
    headers.append('Access-Control-Allow-Origin', '*');
    headers.append('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    headers.append('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return new Response(null, { status: 204, headers });
}