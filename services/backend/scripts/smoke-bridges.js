/*
| Quick local bridge verification:
| user pickup <-> collector status
| collector lot <-> recycler lots feed
| recycler org visible on GET /api/recyclers
*/
const axios = require("axios");

const ROOT = process.env.SMOKE_BASE_URL || "http://127.0.0.1:5000";

async function main() {
  const out = {};

  const recyclers = await axios.get(`${ROOT}/api/recyclers`);
  out.recyclers = {
    count: recyclers.data?.data?.count,
    names: (recyclers.data?.data?.recyclers || []).map((r) => ({
      name: r.name,
      isAuthorized: r.isAuthorized,
    })),
  };

  const collectorLogin = await axios.post(`${ROOT}/api/auth/login`, {
    identifier: "9876543210",
    password: "Pass1234a",
    app: "collector",
  });
  const cToken = collectorLogin.data.data.accessToken;
  out.collector = {
    role: collectorLogin.data.data.user.role,
    name: collectorLogin.data.data.user.fullName,
  };

  const recyclerLogin = await axios.post(`${ROOT}/api/auth/login`, {
    identifier: "9876500001",
    password: "Recycler1a",
  });
  const rToken = recyclerLogin.data.data.accessToken;
  out.recycler = {
    role: recyclerLogin.data.data.user.role,
    organisationName: recyclerLogin.data.data.user.organisationName,
    recyclerId: recyclerLogin.data.data.user.recyclerId,
  };

  const userLogin = await axios.post(`${ROOT}/api/auth/login`, {
    identifier: "9000012345",
    password: "DemoUser1",
    app: "user",
  });
  const uToken = userLogin.data.data.accessToken;
  out.user = {
    role: userLogin.data.data.user.role,
    name: userLogin.data.data.user.fullName,
  };

  const vendors = await axios.get(`${ROOT}/api/user/vendors`, {
    headers: { Authorization: `Bearer ${uToken}` },
  });
  out.vendors = {
    count: vendors.data?.data?.count,
    sample: (vendors.data?.data?.vendors || []).slice(0, 3).map((v) => v.name),
  };

  const clientId = `smoke-${Date.now()}`;
  const lot = await axios.post(
    `${ROOT}/api/lots`,
    {
      materialId: "cable",
      weightKg: 5,
      condition: "Scrap",
      electronicDevice: "Copper Wire",
      notes: "Bridge smoke lot",
      clientId,
    },
    { headers: { Authorization: `Bearer ${cToken}` } }
  );
  const createdLot =
    lot.data?.data?.lot || lot.data?.lot || lot.data?.data;
  out.lotCreate = {
    id: createdLot?.id,
    status: createdLot?.status,
    lotNumber: createdLot?.lotNumber,
  };

  const recyclerLots = await axios.get(`${ROOT}/api/lots?limit=50`, {
    headers: { Authorization: `Bearer ${rToken}` },
  });
  const lotList =
    recyclerLots.data?.data?.lots || recyclerLots.data?.lots || [];
  out.recyclerSeesLot = lotList.some(
    (l) =>
      l.id === out.lotCreate.id ||
      l.clientId === clientId ||
      l.clientReference === clientId ||
      l.lotNumber === out.lotCreate.lotNumber
  );
  out.recyclerLotCount = lotList.length;

  const created = await axios.post(
    `${ROOT}/api/user/requests`,
    {
      collectorId: "963f0dfe-6f22-43e9-9ade-5218d5f270d2",
      pickupAddress: "Kothrud, Pune",
      materialCategory: "Paper",
      materialName: "Newspaper",
      estimatedWeightKg: 10,
      ratePerKg: 14,
      description: "Bridge pickup smoke",
    },
    { headers: { Authorization: `Bearer ${uToken}` } }
  );
  const createdRequest =
    created.data?.data?.request || created.data?.request || created.data?.data;
  const reqId = createdRequest?.id;
  out.userRequest = { id: reqId, status: createdRequest?.status };

  const pickups = await axios.get(`${ROOT}/api/pickup-requests`);
  const requests = pickups.data?.data?.requests || pickups.data?.requests || [];
  const match =
    requests.find((r) => r.id === reqId || r.userRequestId === reqId) || null;
  out.collectorSeesPickup = Boolean(match);
  out.pickupId = match?.id;

  if (match?.id) {
    const accept = await axios.patch(
      `${ROOT}/api/pickup-requests/${match.id}/status`,
      { status: "ACCEPTED" },
      { headers: { Authorization: `Bearer ${cToken}` } }
    );
    const accepted =
      accept.data?.data?.request || accept.data?.request || accept.data?.data;
    out.accept = { status: accepted?.status };

    const poll = await axios.get(`${ROOT}/api/user/requests/${reqId}`, {
      headers: { Authorization: `Bearer ${uToken}` },
    });
    const polled =
      poll.data?.data?.request || poll.data?.request || poll.data?.data;
    out.userPoll = {
      status: polled?.status,
      collectorStatus: polled?.collectorStatus,
    };
  }

  console.log(JSON.stringify(out, null, 2));
}

main().catch((error) => {
  console.error(
    error.response?.data || error.message || error
  );
  process.exit(1);
});
