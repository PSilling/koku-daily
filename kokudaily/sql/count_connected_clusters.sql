SELECT count (*) as "count",
       rm.assembly_id,
       rm.operator_airgapped,
       rm.operator_version,
       rm.cluster_id,
       COALESCE(c.account_id, 'unknown') as account_id,
       p.type as source_type,
       c.org_id
  FROM
    (SELECT provider_id,
        row_number() OVER (PARTITION BY provider_id ORDER BY manifest_creation_datetime DESC) as row_number,
        max(assembly_id) as assembly_id,
        operator_airgapped,
        max(operator_version) as operator_version,
        cluster_id
    FROM public.reporting_common_costusagereportmanifest AS rm
    GROUP BY provider_id,
        operator_airgapped,
        operator_version,
        cluster_id,
        manifest_creation_datetime
    ) as rm
  JOIN public.api_provider AS p
    ON p.uuid = rm.provider_id
  JOIN public.api_customer AS c
    ON c.id = p.customer_id
 WHERE not coalesce(rm.operator_airgapped, true) AND rm.row_number = 1
 GROUP
    BY c.account_id,
       c.org_id,
       rm.assembly_id,
       rm.operator_airgapped,
       rm.operator_version,
       rm.cluster_id,
       source_type
;
