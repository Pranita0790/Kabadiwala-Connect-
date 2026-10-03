/*
|--------------------------------------------------------------------------
| FILE UPLOAD
|--------------------------------------------------------------------------
| Memory storage only. An image is forwarded to the Python AI service as a
| multipart body and never written to this host's disk, so a disk write
| buffer is not needed.
|
| The collector app is required to compress and resize images before upload
| (AGENTS.md section 6); these limits are the server-side backstop for a
| client that does not.
|--------------------------------------------------------------------------
*/

const multer = require("multer");

const config = require("../config/env");
const logger = require("../lib/logger");
const {
  PayloadTooLargeError,
  UnprocessableError,
} = require("../lib/errors");

const ALLOWED = new Set(config.uploads.allowedMimeTypes);

const upload = multer({
  storage: multer.memoryStorage(),

  limits: {
    fileSize: config.uploads.maxImageBytes,
    files: 1,
    fields: 20,
  },

  fileFilter(req, file, callback) {
    if (!file.mimetype?.startsWith("image/")) {
      return callback(
        new UnprocessableError(
          `Only image uploads are supported. Received: ${file.mimetype || "unknown"}`,
          "UNSUPPORTED_MEDIA_TYPE"
        )
      );
    }

    if (!ALLOWED.has(file.mimetype)) {
      return callback(
        new UnprocessableError(
          `Image type ${file.mimetype} is not allowed. ` +
            `Allowed: ${[...ALLOWED].join(", ")}`,
          "UNSUPPORTED_MEDIA_TYPE"
        )
      );
    }

    callback(null, true);
  },
});

/**
 * Single image under the field name `file`, which is the field name the
 * deployed collector app sends (see RemoteAiClassificationService).
 */
const singleImage = upload.single("file");

/**
 * Convert multer's own error objects into the standard error envelope.
 */
function handleUploadErrors(error, req, res, next) {
  if (!error) {
    return next();
  }

  if (error instanceof multer.MulterError) {
    logger.warn("Upload rejected", { code: error.code, path: req.path });

    if (error.code === "LIMIT_FILE_SIZE") {
      return next(
        new PayloadTooLargeError(
          `Image exceeds the ${Math.round(
            config.uploads.maxImageBytes / (1024 * 1024)
          )} MB limit. Compress the photo and try again.`
        )
      );
    }

    return next(
      new UnprocessableError(
        `Upload failed: ${error.message}`,
        `UPLOAD_${error.code}`
      )
    );
  }

  next(error);
}

module.exports = {
  singleImage,
  handleUploadErrors,
};
