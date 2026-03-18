/**
 * PDF Sync Lambda — Single Lambda with path-based routing
 *
 * Routes:
 *   POST /sync/register       — Register a sync code from the iOS app
 *   POST /sync/validate       — Validate a sync code (website)
 *   POST /sync/upload-url     — Get presigned S3 upload URL (website)
 *   POST /sync/confirm-upload — Confirm upload completed (website)
 *   GET  /sync/pending        — Check for pending PDFs (iOS app)
 *   POST /sync/ack            — Mark PDF as downloaded (iOS app)
 *
 * Environment Variables:
 *   S3_BUCKET       — S3 bucket name (e.g. memorize-pdf-uploads)
 *   DYNAMO_TABLE    — DynamoDB table name (e.g. memorize-sync)
 *   AWS_REGION      — AWS region (set automatically by Lambda)
 */

import { DynamoDBClient, PutItemCommand, GetItemCommand, QueryCommand, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import crypto from 'crypto';

const dynamo = new DynamoDBClient({});
const s3 = new S3Client({});
const TABLE = process.env.DYNAMO_TABLE || 'memorize-sync';
const BUCKET = process.env.S3_BUCKET || 'memorize-pdf-uploads';
const CODE_TTL_DAYS = 30;
const FILE_TTL_DAYS = 7;

// CORS headers
const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
};

export const handler = async (event) => {
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 200, headers, body: '' };
    }

    const path = event.path || event.rawPath || '';
    const method = event.httpMethod || event.requestContext?.http?.method || '';

    try {
        if (path.endsWith('/sync/register') && method === 'POST') return await register(event);
        if (path.endsWith('/sync/validate') && method === 'POST') return await validate(event);
        if (path.endsWith('/sync/upload-url') && method === 'POST') return await getUploadUrl(event);
        if (path.endsWith('/sync/confirm-upload') && method === 'POST') return await confirmUpload(event);
        if (path.endsWith('/sync/pending') && method === 'GET') return await getPending(event);
        if (path.endsWith('/sync/ack') && method === 'POST') return await ack(event);

        return respond(404, { error: 'Not found' });
    } catch (err) {
        console.error('Handler error:', err);
        return respond(500, { error: 'Internal server error' });
    }
};

// POST /sync/register — iOS app registers its sync code
async function register(event) {
    const { code } = JSON.parse(event.body || '{}');
    if (!code || code.length !== 6) return respond(400, { error: 'Invalid code' });

    const ttl = Math.floor(Date.now() / 1000) + CODE_TTL_DAYS * 86400;
    await dynamo.send(new PutItemCommand({
        TableName: TABLE,
        Item: {
            PK: { S: `CODE#${code.toUpperCase()}` },
            SK: { S: 'META' },
            createdAt: { S: new Date().toISOString() },
            ttl: { N: String(ttl) },
        },
    }));

    return respond(200, { status: 'ok', code: code.toUpperCase(), expiresAt: new Date(ttl * 1000).toISOString() });
}

// POST /sync/validate — Website validates a sync code exists
async function validate(event) {
    const { code } = JSON.parse(event.body || '{}');
    if (!code || code.length !== 6) return respond(400, { error: 'Invalid code' });

    const result = await dynamo.send(new GetItemCommand({
        TableName: TABLE,
        Key: {
            PK: { S: `CODE#${code.toUpperCase()}` },
            SK: { S: 'META' },
        },
    }));

    if (!result.Item) return respond(404, { status: 'error', message: 'Code not found' });
    return respond(200, { status: 'ok' });
}

// POST /sync/upload-url — Website gets a presigned S3 PUT URL
async function getUploadUrl(event) {
    const { code, filename } = JSON.parse(event.body || '{}');
    if (!code || !filename) return respond(400, { error: 'Missing code or filename' });

    const fileId = crypto.randomUUID();
    const s3Key = `${code.toUpperCase()}/${fileId}.pdf`;

    const command = new PutObjectCommand({
        Bucket: BUCKET,
        Key: s3Key,
        ContentType: 'application/pdf',
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 900 }); // 15 min

    return respond(200, { uploadUrl, fileId });
}

// POST /sync/confirm-upload — Website confirms the upload finished
async function confirmUpload(event) {
    const { code, fileId, filename } = JSON.parse(event.body || '{}');
    if (!code || !fileId) return respond(400, { error: 'Missing code or fileId' });

    const ttl = Math.floor(Date.now() / 1000) + FILE_TTL_DAYS * 86400;
    await dynamo.send(new PutItemCommand({
        TableName: TABLE,
        Item: {
            PK: { S: `CODE#${code.toUpperCase()}` },
            SK: { S: `FILE#${fileId}` },
            filename: { S: filename || 'document.pdf' },
            uploadedAt: { S: new Date().toISOString() },
            status: { S: 'pending' },
            ttl: { N: String(ttl) },
        },
    }));

    return respond(200, { status: 'ok', fileId });
}

// GET /sync/pending?code=XXX — iOS app checks for pending PDFs
async function getPending(event) {
    const code = (event.queryStringParameters?.code || '').toUpperCase();
    if (!code || code.length !== 6) return respond(400, { error: 'Invalid code' });

    const result = await dynamo.send(new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
        FilterExpression: '#s = :pending',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: {
            ':pk': { S: `CODE#${code}` },
            ':prefix': { S: 'FILE#' },
            ':pending': { S: 'pending' },
        },
    }));

    const files = await Promise.all((result.Items || []).map(async (item) => {
        const fileId = item.SK.S.replace('FILE#', '');
        const s3Key = `${code}/${fileId}.pdf`;

        const downloadUrl = await getSignedUrl(s3, new GetObjectCommand({
            Bucket: BUCKET,
            Key: s3Key,
        }), { expiresIn: 900 });

        return {
            fileId,
            filename: item.filename?.S || 'document.pdf',
            uploadedAt: item.uploadedAt?.S || '',
            downloadUrl,
        };
    }));

    return respond(200, { files });
}

// POST /sync/ack — iOS app marks a PDF as downloaded
async function ack(event) {
    const { code, fileId } = JSON.parse(event.body || '{}');
    if (!code || !fileId) return respond(400, { error: 'Missing code or fileId' });

    await dynamo.send(new UpdateItemCommand({
        TableName: TABLE,
        Key: {
            PK: { S: `CODE#${code.toUpperCase()}` },
            SK: { S: `FILE#${fileId}` },
        },
        UpdateExpression: 'SET #s = :downloaded',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: { ':downloaded': { S: 'downloaded' } },
    }));

    return respond(200, { status: 'ok' });
}

function respond(statusCode, body) {
    return { statusCode, headers, body: JSON.stringify(body) };
}
