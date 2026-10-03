/*
|--------------------------------------------------------------------------
| NOTIFICATIONS SCHEMAS
|--------------------------------------------------------------------------
*/

const { z } = require("zod");

const { notificationType } = require("../../config/constants");

const list = {
  query: z
    .object({
      page: z.coerce.number().int().positive().optional(),
      pageSize: z.coerce.number().int().positive().max(100).optional(),
      unreadOnly: z
        .enum(["true", "false"])
        .optional()
        .transform((value) => value === "true"),
    })
    .strip(),
};

const markRead = {
  params: z.object({
    id: z.string().uuid("Notification id must be a UUID"),
  }),
};

const create = {
  body: z.object({
    userId: z.string().uuid(),
    lotId: z.string().uuid().optional(),
    type: z.enum(Object.values(notificationType)),
    titleEn: z.string().min(1).max(200),
    bodyEn: z.string().min(1).max(1000),
    titleHi: z.string().max(200).optional(),
    titleMr: z.string().max(200).optional(),
    bodyHi: z.string().max(1000).optional(),
    bodyMr: z.string().max(1000).optional(),
  }),
};

module.exports = { list, markRead, create };