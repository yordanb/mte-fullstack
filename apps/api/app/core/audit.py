"""Penulis audit log. Gagal tulis tak boleh menggagalkan request."""
from sqlalchemy import text


async def write_log(db, *, user_id=None, username=None, role=None,
                    method="", path="", status=0, ip=None, user_agent=None) -> None:
    try:
        await db.execute(text(
            "INSERT INTO audit_logs(user_id,username,role,method,path,status,ip,user_agent) "
            "VALUES (:u,:n,:r,:m,:p,:s,:ip,:ua)"),
            {"u": user_id, "n": username, "r": role, "m": method[:10],
             "p": path[:500], "s": status, "ip": (ip or "")[:45],
             "ua": (user_agent or "")[:500]})
    except Exception:
        pass
