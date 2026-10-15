# Mapa de literatura → funções do projeto

- **Proveniência:** export da biblioteca Zotero do mantenedor
  (`Minha biblioteca.bib`, 335 entradas — 184 capítulos, 125 artigos, 24
  anais; 363 PDFs associados), recebida em 2026-10-08.
- **Método:** inventário temático sobre títulos/keywords/abstracts do BibTeX.
  Somente itens com DOI ou identificação completa foram promovidos ao mapa;
  PDFs completos permanecem na biblioteca do mantenedor para leitura
  aprofundada quando um epic for aberto.
- **Uso:** enriquecer as funções planejadas dos epics (#4–#12) e a
  fundamentação da ADR 0001. **Nenhuma entrada aqui constitui aprovação de
  design** — cada epic decide o que incorporar na sua tarefa de escopo.

## 1. As duas fontes já citadas na ADR estão na biblioteca

| Referência na ADR | Entrada na biblioteca | Relevância real ao projeto |
|---|---|---|
| Kumar & Vaishnava (2025), DOI 10.1109/MRIE66930.2025.11156708 | "Adapting ML Systems for Estimating Tourist Flows in Sustainable Tourism Using Cloud and Cyber Integrated" | Framework **CST-FEML**: ensemble ML federado com interação cloud-edge para estimar fluxo turístico **preservando privacidade** (treinamento distribuído). Alinha-se diretamente com a Opção C da ADR (backend autoritativo + edge leve) e com o epic #12 — é precedente arquitetural, não recomendação de offline (conforme redação corrigida no PR #28). |
| Hernández-Cabrera et al. (2024), DOI 10.1007/978-3-031-52607-7_13 | "Big Data in Real Time for the Management of Tourist Destinations: The TOURETHOS Platform Technological Model" | Plataforma real de **big data em tempo real** para gestão de destinos (consolidação multi-fonte + IA). Precedente concreto para o Hub como camada de leitura realtime (projeções por audiência, §6/§8 da ADR). |

## 2. Mapeamento por epic

### #4 — Operação do atrativo (fila, ciclos, ETA, dois painéis de TV)

| Estudo | O que enriquece |
|---|---|
| Bollenbach et al. (2024), DOI 10.1007/s40558-024-00291-2 — *"Enabling active visitor management: local, short-term occupancy prediction at a touristic point of interest"* | O mais próximo do nosso caso: previsão de ocupação **local e de curto prazo** num POI livre — diretamente aplicável à fila do fervedouro e ao ETA exibido no painel. Leitura prioritária para a tarefa de ETA da #4. |
| Neubig et al. (2024), DOI 10.1007/978-3-031-58839-6_16 — *"Beyond Sensors: A Rule-Based Approach for Cost-Effective Visitor Guidance"* | Abordagem **baseada em regras** (não em sensores densos) para orientação de visitantes com baixo custo — combina com a coleta manual por tablet do Jalapão e sugere que o painel de TV pode funcionar com regras sobre os contadores antes de qualquer ML. |
| Putjorn et al. (2025), DOI 10.1109/ECTIDAMTNCON64748.2025.10962002 — *"Exploring Generative AI for Dynamic Carrying Capacity Assessment in Mountainous and Cave Areas"* | **Capacidade de carga dinâmica** em áreas naturais restritas (framework SAFER) — análogo estrutural dos fervedouros (poços com limite de banhistas por ciclo). Subsidia o ciclo fila→água→concluído e limites adaptativos. |
| de Almeida et al. (2025), DOI 10.1007/978-3-031-83705-0_7 — *"A Carrying Capacity Calculator for Pedestrians Using OpenStreetMap Data"* | Calculadora de capacidade com dados OSM — método reproduzível e aberto para estimar lotação física dos atrativos sem sensoriamento proprietário. |

### #7 — Experiência pública do turista (PWA/QR com status e espera)

| Estudo | O que enriquece |
|---|---|
| Calvaresi et al. (2021), DOI 10.1007/978-3-030-65785-7_1 — *"The Evolution of Chatbots in Tourism: A Systematic Literature Review"* | Revisão sistemática de chatbots turísticos — taxonomia para decidir **se/quando** o PWA ganha camada conversacional (ou permanece informativo passivo). |
| Benaddi et al. (2025), sem DOI no .bib — *"Enhancing Smart Tourism With Chatbots: Metamodel of Domain-Specific Language"* | Metamodelo DSL para chatbots de destino — referência de modelagem se a #7 evoluir para assistente com informação responsável. |
| Kim et al. (2023), DOI 10.1080/10941665.2023.2247099 — *"Why do tourists use public transport in Korea?"* | Papel do conhecimento de IA do turista e de fatores ESG na adoção — base para o tom da comunicação pública (adoption gap em público não técnico). |

### #9 — Governança ambiental (limites, pressão, incidentes, decisão humana)

| Estudo | O que enriquece |
|---|---|
| Putjorn et al. (2025) — SAFER (ver #4) | Limites dinâmicos de capacidade com engajamento comunitário — eixo central da #9. |
| Sarigiannidis et al. (2024), DOI 10.1007/978-3-031-54338-8_31 — *"Environmental Management Accounting System for Sustainable Tourism Based on Business Intelligence"* | Contabilidade de gestão ambiental + BI — modelo para os indicadores de pressão que o painel do coordenador deve expor (não só contagem: custo/pressão ambiental por visitante). |
| Sarigiannidis et al. (2025), DOI 10.1007/978-3-031-78471-2_34 — *"Innovative Pathways to Sustainable Tourism in Greece: Open Environmental Accounting"* | Contabilidade ambiental aberta — transparência de indicadores para órgãos públicos (SEPLAN/FAPT). |

### #10 — Imagem ao vivo + snapshot/hora para pesquisa (privacidade por desenho)

| Estudo | O que enriquece |
|---|---|
| Ruiz-Diaz-Medina et al. (2025), DOI 10.13053/CyS-29-2-5040 — *"Vehicle Counting System Using Image Processing with Pre-trained ML Models"* | Contagem de veículos por imagem com modelos pré-treinados — técnica diretamente aplicável a snapshots horários (contar sem identificar = privacidade por desenho). |
| Franco et al. (2024), DOI 10.1007/978-3-031-52607-7_2 — *"Tracking Tourist Flows Through Wi-Fi Sensor Technology in Seville"* | Rastreio via Wi-Fi — alternativa não visual a câmeras, mas com risco de PII (MAC) que a #10 precisará tratar explicitamente na política de mídia. |
| Nazurally et al. (2025), DOI 10.1007/s41976-025-00243-2 — *"Automated Shoreline Detection in Mauritius: Canny Edge Detection"* | Processamento de imagem costeira com método clássico — precedente de pipeline de visão leve para ambientes naturais (sem edge pesado). |

### #11 — Plataforma de dados e pesquisa (eventos canônicos, exportações)

| Estudo | O que enriquece |
|---|---|
| Alderighi et al. (2025), DOI 10.1371/journal.pone.0335190 — *"MONTUR project: Dataset for understanding and forecasting tourist flows"* | **Dataset público** (41M passagens, Vale de Aosta, sensores distribuídos + ML) — benchmark para validar formatos de série temporal do Jalapão e referência de publicação de dados abertos de turismo. |
| Sitthi et al. (2021), DOI 10.1007/978-3-030-62066-0_8 — *"Sustainable Tourism: Crowdsourced Data for Natural Scene and Tag Mining"* | Dados crowdsourced para mineração de cenas naturais — relevante para a frente de cartografia/DRP (domínio separado, §1 da ADR). |
| Gu et al. (2019), DOI 10.3390/ijgi8070314 — *"Regionalization analysis and mapping for the source and sink of tourist flows"* | Regionalização origem→destino — enriquece a análise de `originCity` já coletada pelo app. |

### #12 — AI readiness (previsão de ocupação, ETA, anomalias, recomendação)

| Estudo | O que enriquece |
|---|---|
| Wang, Changlong et al. (2025), sem DOI no .bib — *"High-Frequency Tourist Flow Forecasting with GRU + Attention"* | GRU+atenção para previsão em alta frequência — candidato natural quando houver série densa por atrativo. |
| Wang, Wei et al. (2021), DOI 10.1145/3424220 — *"A Multi-graph Convolutional Network Framework for Tourist Flow Prediction"* | Multi-grafo (POIs relacionados) — modela o **território como rede** de atrativos, não pontos isolados: a saída de um fervedouro prevê a chegada no próximo. |
| Yang et al. (2025), DOI 10.3390/informatics12030089 — *"GA-ACO-BP Neural Network"*, Wei et al. (2024) — *"Self-organized Migration + DL"*, Zhang et al. (2020), DOI 10.1080/10941665.2019.1709876 — *"Deep learning com dados de busca"*, Kang et al. (2019), DOI 10.1088/1757-899X/490/4/042001 — *"Multiple Additive Regression Tree"* | Comparativo de famílias de modelo para a fase de experimentação — úteis como baseline quando a série histórica do piloto existir. |
| Tzitziou et al. (2024), DOI 10.1007/978-3-031-63227-3_34 — *"Tourist Flow Projection in Response to Weather Variability"* (BIRCH) | Variável **clima** como feature — chuvoso/fechado muda fila do fervedouro; sugere covariável meteorológica no schema de eventos (#23). |
| Giménez-Manuel et al. (2024), DOI 10.1049/smc2.12085 — *"BERT-based occupancy prediction, Torrevieja"* | Ocupação prevista onde dados hoteleiros são escassos — análogo ao Jalapão (pousadas pequenas, sem PMS). |
| Kumar et al. (2025) — CST-FEML (ver §1) | Aprendizado federado cloud-edge com privacidade — responde ao dilema LGPD + conectividade do #12. |
| Majic et al. (2023), DOI 10.1007/978-3-031-25752-0_27 — *"Tourist Flow Simulation in GAMA"* | Simulação baseada em agentes parametrizada por histórico — permite testar cenários de limite/capacidade (#9) antes de impor regra real. |
| Orama et al. (2022), DOI 10.3390/app12125834 — *"Mobility Patterns of Clusters of City Visitors"* | Padrões de mobilidade por cluster — base para agrupamento de perfis de visita do território. |

### #2 / ADR 0001 — arquitetura, conectividade e edge

| Estudo | O que enriquece |
|---|---|
| Jusak et al. (2023), DOI 10.1007/978-981-99-2909-2_13 — *"IoT Conceptual Model and UX Design for Forest Hiking Systems in the Tropics"* | **O mais próximo do nosso contexto físico**: IoT+UX para trilha em floresta tropical — conectividade irregular e UX honesta sob degradação (§4–§5 da ADR). Leitura prioritária antes de fechar a interpretação estrita "sem banco local" (D-C). |
| Chen et al. (2025), DOI 10.3390/tourhosp6040199 — *"Edge-Enhanced Federated Optimization for Real-Time Trip"* | Edge+federado para decisão em tempo real — precedente de computação na borda quando a nuvem falha; relaciona-se com a exceção nomeada da §4.2. |
| Wang, Wei et al. (2020), sem DOI no .bib — *"Realizing the Potential of IoT for Smart Tourism with 5G and AI"* | Panorama IoT+5G+IA para turismo — enquadramento do gap de cobertura: o Jalapão não tem 5G, o que reforça a modelagem F1–F7. |

## 3. Ressalvas de transferência

- **Densidade de dados:** quase todos os modelos de previsão assumem sensores
  ou séries horárias densas. O Jalapão tem **contagem manual esparsa** por
  tablet — a #12 deve começar por métodos robustos a dados escassos (regras +
  baseline estatístico) antes de DL. Bollenbach (2024) e Neubig (2024) são os
  mais transferíveis justamente por operar com instrumentação mínima.
- **Contexto geográfico:** a maioria dos estudos é urbana ou de destino com
  conectividade ampla. Jusak (2023) e a frente CST-FEML são as exceções —
  tratar o resto como transferência, não como validação de campo.
- **Privacidade:** Wi-Fi tracking (Franco 2024) e imagem ao vivo (#10)
  precisam passar pela matriz #19 e pela política de mídia antes de qualquer
  protótipo — MAC e face são PII.
- **Sem validação de campo:** este mapa é triagem bibliográfica; nenhuma
  alegação de acurácia foi reproduzida localmente.

## 4. Leitura prioritária sugerida

1. Bollenbach 2024 (ocupação local de curto prazo) → #4/#12
2. Jusak 2023 (IoT trilha tropical, conectividade) → #2/D-C
3. Putjorn 2025 (capacidade dinâmica áreas naturais) → #4/#9
4. MONTUR 2025 (dataset + arquitetura de sensoriamento) → #11/#12
5. TOURETHOS 2024 (big data em tempo real de destino) → #2/Hub

## 5. Reconciliação de relay (Issue #35)

- Os commits de nuvem citados no protocolo A2A (`9e8edf5`, `7ad2343`) não
  estavam acessíveis no `origin` no momento do relay.
- A reconciliação contra a `main` pós-PRs #28/#33 indica que este mapa já
  incorpora os pontos reportados nesses resumos: delimitação da fundamentação,
  correção de extrapolações e recomendações objetivas por epic.
- Pendência residual explícita: leituras completas dos PDFs e eventual ajuste de
  priorização permanecem dependentes da abertura das tarefas executáveis de cada
  epic, sem mudança funcional nesta entrega documental.
