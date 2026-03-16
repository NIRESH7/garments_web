import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { S3Client } from '@aws-sdk/client-s3';
import multerS3 from 'multer-s3';
import dotenv from 'dotenv';

dotenv.config();

const isS3Configured = process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY && process.env.AWS_BUCKET_NAME;

const s3 = isS3Configured ? new S3Client({
    region: process.env.AWS_REGION || 'us-east-1',
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    }
}) : null;

const storage = isS3Configured ?
    multerS3({
        s3: s3,
        bucket: process.env.AWS_BUCKET_NAME,
        metadata: function (req, file, cb) {
            cb(null, { fieldName: file.fieldname });
        },
        key: function (req, file, cb) {
            cb(null, `uploads/${Date.now().toString()}-${file.originalname}`);
        }
    }) :
    multer.diskStorage({
        destination(req, file, cb) {
            const dir = 'uploads/';
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
            cb(null, dir);
        },
        filename(req, file, cb) {
            cb(null, `${file.fieldname}-${Date.now()}${path.extname(file.originalname)}`);
        },
    });

function checkFileType(file, cb) {
    const allowedExt = /\.(jpg|jpeg|png|m4a|mp3|wav|aac|mp4|webm|caf)$/i;
    const allowedMime = /^(image\/(jpeg|jpg|png)|audio\/(mpeg|mp3|wav|x-wav|aac|x-aac|mp4|x-m4a|m4a|webm|caf)|application\/octet-stream)$/i;

    const extOk = allowedExt.test(path.extname(file.originalname || '').toLowerCase());
    const mimeOk = allowedMime.test((file.mimetype || '').toLowerCase());

    if (extOk || mimeOk) {
        return cb(null, true);
    } else {
        cb(new Error(`Invalid file type: ${file.mimetype || 'unknown'} (${file.originalname || 'no-name'})`));
    }
}

const upload = multer({
    storage,
    fileFilter: function (req, file, cb) {
        checkFileType(file, cb);
    },
});

export default upload;
