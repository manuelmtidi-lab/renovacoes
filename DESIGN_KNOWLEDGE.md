# DESIGN_KNOWLEDGE.md

Referência de design para interfaces web na stack **Django + PostgreSQL + HTML5 + Tailwind CSS + HTMX + JavaScript mínimo**.

Pesquisa feita em 19/11/2026. Este ficheiro não altera nenhum ficheiro funcional do projecto.

## 0. Como ler este documento (estado de verificação)

Cada afirmação traz uma etiqueta, para nunca se confundir o que foi lido com o que é opinião.

| Etiqueta | Significado |
|---|---|
| **[VISTO]** | Li a página ou o código-fonte nesta pesquisa. |
| **[PARCIAL]** | Li só parte (um excerto, a landing page, a descrição). |
| **[NÃO VISTO]** | Não consegui aceder. Não afirmo nada sobre o conteúdo. |
| **[RECOMENDAÇÃO]** | Opinião minha, derivada do que li e do contexto do projecto. Não vem de nenhuma fonte. |
| **[NÃO TESTADO]** | Código que escrevi com base no que li, mas que não corri num navegador. Testar antes de usar. |

---

## 1. Fontes de inspiração: o que consegui analisar

| Fonte | Estado | O que consegui |
|---|---|---|
| Aceternity UI (ui.aceternity.com) | **[PARCIAL]** | Landing, catálogo completo de componentes/blocos, página do Bento Grid. O separador "Code" não é servido, por isso o código dos componentes veio de espelhos (21st.dev e blogue oficial). Os blocos Pro (sidebars, login, empty states) só mostram nomes. |
| Magic UI (magicui.design) | **[VISTO]** | Landing, `llms.txt` e código completo de Marquee e Border Beam, com as animações CSS. Licença MIT (README do repositório). |
| React Bits (reactbits.dev) | **[PARCIAL]** | Landing e README do GitHub. Não li o código de nenhum componente. |
| Skiper UI (skiper-ui.com) | **[PARCIAL]** | Landing. A maior parte é premium (pago). Há cerca de 24 componentes gratuitos, instalados por `shadcn`. Não li código. |
| Motion Primitives (motion-primitives.com) | **[NÃO VISTO]** | O site bloqueia acesso automático (`robots`). Nada a registar. |
| Awwwards (awwwards.com) | **[PARCIAL]** | A página devolveu só a navegação (nomeados, vencedores, colecções, directório). Sem exemplos analisáveis. |
| Godly (godly.website) | **[PARCIAL]** | O endereço redireccionou para `recent.design`, uma galeria de inspiração (web, motion, interface, branding). É uma galeria de imagens, sem código. |
| Motion (motion.dev), Lenis, GSAP, HTMX | **[VISTO]** | Documentação e READMEs oficiais, citados na secção 5. |
| Three.js | **[NÃO VISTO]** | Não pesquisei. Só o menciono como contexto. |

**Licenças.** Magic UI é MIT. O Aceternity indica MIT nos componentes gratuitos (listagem do 21st.dev), mas o site tem uma página de licença própria que **não li**. Os blocos, templates e páginas "Pro" são pagos e **não se copiam**. Para o React Bits, as fontes que vi discordam (MIT vs. "MIT + Commons Clause"): **confirmar no `LICENSE.md` antes de reutilizar código**. O GSAP é gratuito, incluindo os plugins, sob a licença "no charge" da GreenSock (**[VISTO]** no README oficial); o texto da licença não o li.

---

## 2. Bibliotecas e componentes relevantes

Quase todas são **React**. Servem para perceber o efeito, não para instalar.

### Aceternity UI [PARCIAL]
React + Tailwind + Motion, instalação por `shadcn`. Catálogo lido (118+ componentes gratuitos):
- **Cartões:** Card Spotlight, Wobble Card, 3D Card Effect, Glare Card, Card Hover Effect, Direction Aware Hover.
- **Fundos:** Aurora, Background Beams, Grid and Dot Backgrounds, Meteors, Spotlight, Glowing Effect.
- **Scroll:** Sticky Scroll Reveal, Parallax Scroll, Container Scroll Animation, Tracing Beam.
- **Texto:** Text Generate Effect, Typewriter, Flip Words, Text Reveal Card.
- **Navegação/formulários:** Floating Navbar, Sidebar, Tabs, Signup Form, File Upload, Animated Modal.
- **Dados:** Timeline, World Map, GitHub Globe.

### Magic UI [VISTO]
150+ componentes, React + Tailwind + Motion, MIT. Os mais úteis para este projecto:
- **Marquee:** animação CSS pura (secção 5.3).
- **Border Beam:** animação CSS pura (secção 5.2).
- **Shine Border, Meteors, Retro Grid, Number Ticker, Animated List, Bento Grid:** vistos só pelo nome/descrição em `llms.txt`.

### React Bits [PARCIAL]
130+ componentes em 4 variantes (JS-CSS, JS-TW, TS-CSS, TS-TW), em 5 categorias: texto, animações, componentes, fundos, micro-interacções. Há portes oficiais para Vue e Svelte, o que confirma que os efeitos não dependem de React.

### Skiper UI [PARCIAL]
Componentes "pouco comuns" (Dynamic Island, image reveal, cursor trail). Inspirado em Devouring Details, de Rauno Freiberg, que cita como referência de microinteracção. Maioritariamente pago.

---

## 3. Técnicas de animação identificadas

Cada efeito reduz-se a uma técnica base. Isto é o que importa, porque a biblioteca em que veio é descartável.

| Efeito | Técnica real | Precisa de JS? | Fonte |
|---|---|---|---|
| Marquee infinito | `@keyframes` com `translateX(calc(-100% - var(--gap)))` em blocos repetidos, `animation-play-state: paused` ao hover | Não | **[VISTO]** Magic UI |
| Border Beam | Pseudo-elemento animado com `offset-distance` 0→100% ao longo de `offset-path`, recortado por máscara (`mask-composite`) para só aparecer na borda | Não | **[VISTO]** keyframes e máscara; **[PARCIAL]** o `offset-path` |
| Card Spotlight | Posição do rato relativa ao cartão (`getBoundingClientRect`) → `radial-gradient(Npx circle at X Y, ...)` usado como fundo ou máscara | Pouco (só ler o rato) | **[VISTO]** Aceternity |
| Revelação ao scroll | `IntersectionObserver` (em Motion: `inView`) a disparar `opacity`/`translateY` | Pouco | **[VISTO]** Motion |
| Animação ligada ao scroll (parallax, barra de progresso) | `scroll()` do Motion usa a API `ScrollTimeline` quando existe (acelerada por hardware) | Sim | **[VISTO]** motion.dev |
| Scroll suave | Lenis move o scroll nativo com easing; compatível com `scroll()` do Motion | Sim | **[VISTO]** |
| Transições de conteúdo (HTMX) | Classes `htmx-swapping`, `htmx-added`, `htmx-settling` + CSS transitions; ou `transition:true` (View Transitions API) | Não | **[VISTO]** docs do HTMX |
| Efeitos 3D, partículas, shaders | WebGL/Three.js (Aceternity: Cloud Shader, Dither Shader, 3D Globe) | Sim, pesado | **[PARCIAL]** só os nomes |

---

## 4. Padrões de composição visual

Estes padrões vêm do que se vê nos catálogos (Bento Grids, hero sections, glassmorphism, Floating Dock). A descrição de cada um é **[RECOMENDAÇÃO]** minha, não extraída de código.

- **Bento grid.** Mosaico assimétrico de cartões de tamanhos diferentes, que colapsa para uma coluna no telemóvel. A página do Aceternity descreve-o assim. Em Tailwind: `grid grid-cols-1 md:grid-cols-3 gap-4` e `md:col-span-2` nos cartões grandes. Bom para o painel (KPIs de tamanhos diferentes), mau para tabelas.
- **Hierarquia por contraste de superfície.** Fundo → cartão → elemento elevado, com 2-3 níveis de cinza e bordas de 1px de baixa opacidade, em vez de sombras pesadas.
- **Tipografia.** Uma só família sans-serif bem escolhida, com 2-3 tamanhos e 2 pesos. Números tabulares (`tabular-nums`) em tabelas e KPIs.
- **Uma cor de acento.** O resto é neutro. As cores semânticas (vermelho/laranja/amarelo/verde) ficam reservadas aos estados.
- **Glassmorphism** (`backdrop-blur` + fundo semitransparente): só em elementos flutuantes (menu, modal), nunca em tabelas.

---

## 5. Exemplos de implementação (na stack: HTML + Tailwind/CSS + JS mínimo)

> Todo este código é **[NÃO TESTADO]**: escrevi-o a partir das técnicas lidas, sem o correr num navegador. Testar em Chrome e Firefox antes de usar.

### 5.1 Spotlight Card (sem React)

Técnica do Card Spotlight do Aceternity, convertida para variáveis CSS. Usa delegação de eventos, por isso continua a funcionar depois de um swap do HTMX.

```html
<div class="spot-card group relative overflow-hidden rounded-xl border border-slate-200 bg-white p-5 dark:border-slate-800 dark:bg-slate-900">
  <div class="spot-glow pointer-events-none absolute -inset-px opacity-0 transition-opacity duration-300 group-hover:opacity-100"></div>
  <div class="relative">
    <!-- conteúdo do cartão -->
  </div>
</div>
```

```css
.spot-glow {
  background: radial-gradient(240px circle at var(--x, 50%) var(--y, 50%),
              rgb(99 102 241 / 0.14), transparent 80%);
}
@media (hover: none) { .spot-glow { display: none; } }
```

```js
document.addEventListener('pointermove', (e) => {
  const card = e.target.closest?.('.spot-card');
  if (!card) return;
  const r = card.getBoundingClientRect();
  card.style.setProperty('--x', `${e.clientX - r.left}px`);
  card.style.setProperty('--y', `${e.clientY - r.top}px`);
});
```

### 5.2 Border Beam (CSS puro)

Reconstituído a partir do código do Magic UI. Os keyframes e a máscara são do original; o `offset-path` não estava visível no excerto que li, por isso é uma reconstrução. Usar só em 1 elemento de destaque (um cartão de preço, um botão de acção principal), nunca em listas.

```css
.beam {
  position: absolute; inset: 0; border-radius: inherit;
  border: 1px solid transparent; pointer-events: none;
  mask: linear-gradient(transparent, transparent), linear-gradient(#fff, #fff);
  mask-clip: padding-box, border-box;
  mask-composite: intersect;
}
.beam::after {
  content: ""; position: absolute; aspect-ratio: 1; width: 60px;
  background: linear-gradient(to left, #6366f1, #a855f7, transparent);
  offset-anchor: 90% 50%;
  offset-path: rect(0 auto auto 0 round 60px);
  animation: beam 6s linear infinite;
}
@keyframes beam { to { offset-distance: 100%; } }
@media (prefers-reduced-motion: reduce) { .beam::after { animation: none; } }
```

O contentor tem de ter `position: relative` e `overflow: hidden`.

### 5.3 Marquee (CSS puro, código do Magic UI adaptado)

Útil numa landing page (logótipos de clientes), não no painel.

```css
@keyframes marquee {
  from { transform: translateX(0); }
  to   { transform: translateX(calc(-100% - var(--gap))); }
}
.marquee { display: flex; overflow: hidden; gap: var(--gap); --gap: 1rem; --duration: 40s; }
.marquee__track { display: flex; flex-shrink: 0; gap: var(--gap); animation: marquee var(--duration) linear infinite; }
.marquee:hover .marquee__track { animation-play-state: paused; }
@media (prefers-reduced-motion: reduce) { .marquee__track { animation: none; } }
```

A estrutura são 2-4 blocos `.marquee__track` iguais lado a lado (o original repete 4). Os blocos repetidos devem levar `aria-hidden="true"`.

### 5.4 Número que sobe (para os cartões do painel)

Não vem de nenhuma fonte lida; é um padrão comum, escrito por mim.

```js
function countUp(el) {
  const end = Number(el.dataset.countup);
  const fmt = (n) => n.toLocaleString('pt-PT');
  if (el.dataset.done || matchMedia('(prefers-reduced-motion: reduce)').matches) {
    el.textContent = fmt(end); return;
  }
  el.dataset.done = '1';
  const t0 = performance.now(), dur = 800;
  const tick = (t) => {
    const p = Math.min((t - t0) / dur, 1);
    el.textContent = fmt(Math.round(end * (1 - Math.pow(1 - p, 3))));
    if (p < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}
htmx.onLoad((root) => root.querySelectorAll('[data-countup]').forEach(countUp));
```

**Cuidado com o painel que se actualiza a cada 30 s (fase 6).** Cada actualização cria elementos novos e voltaria a animar do zero. Em actualizações periódicas, mostrar o valor final sem animar; animar só no primeiro carregamento.

### 5.5 Revelação ao scroll (Motion, vanilla)

API lida na documentação do Motion (`animate`, `inView`, `stagger`). Fixar uma versão em vez de `@latest`.

```html
<script src="https://cdn.jsdelivr.net/npm/motion@VERSAO_FIXA/dist/motion.js"></script>
<script>
  const { animate, inView } = Motion;
  inView('.reveal', ({ target }) => {
    animate(target, { opacity: [0, 1], y: [16, 0] }, { duration: 0.5 });
  });
</script>
```

Com `.reveal { opacity: 0; }` no CSS e uma regra `prefers-reduced-motion` que a anule.

### 5.6 Transições com HTMX (só CSS, padrões da documentação oficial)

```css
/* Linha que desaparece ao apagar: usar hx-swap="outerHTML swap:300ms" */
tr.htmx-swapping { opacity: 0; transition: opacity 300ms ease-out; }

/* Conteúdo novo que entra: usar hx-swap="outerHTML settle:300ms" */
.row-new.htmx-added { opacity: 0; }
.row-new { opacity: 1; transition: opacity 300ms ease-in; }

/* Feedback de pedido em curso */
.htmx-request { opacity: .6; transition: opacity 200ms linear; }
```

Para transições entre vistas inteiras: `hx-swap="innerHTML transition:true"` (View Transitions API). Confirmar o suporte nos navegadores dos utilizadores antes de depender disto.

---

## 6. Tecnologias recomendadas e papel de cada uma

| Tecnologia | Papel | Quando usar | Quando NÃO usar |
|---|---|---|---|
| **HTML5 semântico** | Estrutura e acessibilidade (`<table>`, `<nav>`, `<button>`) | Sempre | — |
| **Tailwind CSS** | Estilo e responsividade | Sempre | — |
| **CSS moderno** (`@keyframes`, variáveis, `@media`, `backdrop-filter`) | Animações simples e estados | Hover, marquee, beam, fades | Efeitos ligados ao scroll complexos |
| **HTMX** | Interacção com o servidor sem recarregar | Filtros, painel, renovações | Animação de scroll |
| **JS vanilla** (poucas linhas) | Rato, contadores, modais | Spotlight, count-up | Lógica de negócio |
| **Motion (vanilla)** | Animações em JS: scroll-triggered, scroll-linked, springs. `animate` mini = 2.3 kB | Landing pages, quando CSS não chega | Painéis administrativos |
| **Lenis** | Scroll suave | Só landing pages | Painel: tabelas com scroll interno exigem `allowNestedScroll`, e o scroll suave vai contra a legibilidade de dados |
| **GSAP** | Timelines complexas, ScrollTrigger, SplitText | Storytelling longo numa landing | Projectos pequenos: Motion chega |
| **Three.js** | 3D/WebGL | Hero visual muito específico | Dashboards. Peso e esforço desproporcionados |

**Notas lidas na documentação:**
- O Lenis respeita `prefers-reduced-motion` por defeito **desde a versão 1.3.26**; em versões anteriores é preciso não o criar nesse caso (**[VISTO]** em motion.dev/docs/lenis).
- O Motion e o Lenis são compatíveis: o Lenis move o scroll nativo, por isso `scroll()` continua a funcionar.
- O GSAP e os seus plugins (ScrollTrigger, SplitText, etc.) são gratuitos (**[VISTO]**).

---

## 7. Compatibilidade com a stack (Django + Tailwind + HTMX)

| Efeito / componente | Compatível? | Como |
|---|---|---|
| Marquee, Border Beam | **Sim, directo** | CSS puro (secções 5.2 e 5.3) |
| Spotlight, Glow | **Sim** | CSS + 6 linhas de JS (5.1) |
| Bento grid, cartões, sidebar, formulários | **Sim** | Só Tailwind; reconstruir em HTML |
| Reveal ao scroll, count-up | **Sim** | Motion vanilla ou JS próprio |
| Transições de conteúdo | **Sim, nativo** | HTMX + CSS |
| Aurora/gradientes animados | **Sim** | CSS (`@keyframes` num gradiente grande) |
| Efeitos que exigem estado React (Floating Dock, layout animations, shared layout) | **Difícil** | Reimplementar à mão, com custo alto; evitar |
| Shaders, 3D Globe, partículas | **Possível, não recomendado** | WebGL/Three.js; peso e manutenção |

**Regras para a stack:**
1. O código React é para **ler**. Reconstrói-se em HTML + Tailwind e `{% include %}` do Django. Nunca se instala React.
2. Cada efeito vai para um ficheiro de CSS ou JS próprio, e cada componente para um `{% include %}`. O Manuel tem de conseguir explicar cada linha.
3. Tailwind v3 usa `tailwind.config.js` para `keyframes`/`animation` (era o que os exemplos antigos mostravam); o v4 usa `@theme` no CSS. Os exemplos acima usam CSS simples para funcionarem nos dois. Decidir a versão antes de usar a CLI standalone.
4. **Ficheiros estáticos:** dependências por CDN ou ficheiros locais em `static/`, com versão fixa. Nada de `@latest` em produção.
5. **HTMX:** qualquer JS que afecte elementos criados dinamicamente deve usar delegação de eventos ou `htmx.onLoad`.

---

## 8. Recomendações para dashboards

**[RECOMENDAÇÃO]** minha, aplicada ao painel de renovações. As fontes lidas são sobretudo para landing pages; para dashboards não vi código que usar.

**Princípio:** num painel administrativo, o movimento serve para dar feedback, não para impressionar. A velocidade e a legibilidade valem mais do que o efeito.

**Usar:**
- Fades curtos (150-300 ms) em actualizações HTMX.
- Estado de carregamento visível (`htmx-request`).
- Hover subtil em linhas e cartões (mudança de fundo, não de tamanho).
- Count-up só no primeiro carregamento.
- `prefers-reduced-motion` respeitado em tudo.

**Evitar:** parallax, scroll suave, fundos animados, beams, partículas, 3D. Competem com os dados e custam desempenho em portáteis fracos e ligações lentas (relevante em Luanda).

**Estados de alerta (os 4 do projecto).** Nunca só por cor: texto + cor (e opcionalmente ícone), para daltonismo e leitura rápida.

| Estado | Classes Tailwind sugeridas | Texto |
|---|---|---|
| atrasado | `bg-red-100 text-red-800` (escuro: `dark:bg-red-950 dark:text-red-200`) | "Atrasado" |
| 7 dias | `bg-orange-100 text-orange-800` | "≤ 7 dias" |
| 30 dias | `bg-yellow-100 text-yellow-800` | "≤ 30 dias" |
| ok | `bg-green-100 text-green-800` | "Em dia" |

**Estrutura:**
- Cartões KPI (4: esta semana, este mês, em atraso, receita prevista) numa grelha `grid-cols-2 lg:grid-cols-4`; margem num cartão largo.
- Tabelas: cabeçalho fixo, `tabular-nums` nas colunas de valores, alinhamento à direita para números, linhas com 44 px de altura no mínimo (toque), scroll horizontal dentro do contentor em ecrãs pequenos (`overflow-x-auto`), nunca na página.
- Sidebar fixa em `lg:`; em telemóvel, menu num painel deslizante.
- Formulários: rótulo sempre visível (não só placeholder), erro junto ao campo, foco com anel visível (`focus-visible:ring-2`).
- Estados vazios com instrução ("Ainda não há serviços. Adicione o primeiro."), em vez de uma tabela vazia.
- Notificações do Django (`messages`) como "toasts" que desaparecem sozinhos, mas só se o texto continuar acessível (`role="status"`).

---

## 9. Recomendações para landing pages

**[RECOMENDAÇÃO]**, a usar se o projecto vier a ter uma página pública. Aqui sim, as bibliotecas lidas são relevantes.

- **Estrutura:** hero → prova social (logótipos, marquee) → funcionalidades (bento grid) → como funciona → preços/contacto → rodapé. É a mesma ordem dos 5 exemplos de "pages" do Aceternity (Navbar, Hero, Logo cloud, Features, Testimonials, Pricing, CTA, Footer).
- **Movimento permitido:** reveal ao scroll, marquee, spotlight, um único efeito de destaque no hero. Motion vanilla chega; GSAP só para storytelling longo.
- **Lenis** é opcional e só aqui. Se usar, desactivar para quem tem `prefers-reduced-motion` (automático desde a 1.3.26) e testar a navegação por teclado.
- **Desempenho:** imagens em WebP com dimensões declaradas, fontes com `font-display: swap`, animar só `transform` e `opacity`.

---

## 10. Critérios de qualidade (checklist antes de dar uma interface por pronta)

- [ ] Funciona e lê-se bem a 360 px e a 1280 px de largura.
- [ ] Contraste de texto suficiente (mínimo 4.5:1) nos dois temas, se houver tema escuro.
- [ ] Todo o fluxo é utilizável só com teclado; o foco é visível.
- [ ] `prefers-reduced-motion` respeitado em todas as animações.
- [ ] Só `transform`/`opacity` animados; nenhuma animação em tabelas grandes.
- [ ] Uma só cor de acento, uma só família tipográfica, espaçamentos da escala do Tailwind.
- [ ] Nenhuma dependência nova sem justificação escrita.
- [ ] O Manuel sabe explicar cada classe e cada linha de JS.

---

## 11. Limitações conhecidas desta pesquisa

1. **Não li o código-fonte dos componentes React Bits, Skiper UI nem da maioria dos do Aceternity.** O separador de código do Aceternity não é servido; só vi excertos de Card Spotlight, Evervault Card e Input, via espelhos.
2. **Motion Primitives** bloqueia acesso automático: sem informação.
3. **Awwwards e Godly** não deram exemplos analisáveis. O Godly redireccionou para outra galeria.
4. **Three.js** não foi pesquisado.
5. **O código da secção 5 não foi testado** num navegador.
6. **As recomendações para dashboards (secção 8) e landing pages (secção 9) são minhas**, não derivadas de código lido.
7. **Licenças:** confirmar a do React Bits e a página de licença do Aceternity antes de reutilizar qualquer código.
8. As bibliotecas mudam depressa; conferir versões e preços quando forem necessários.

---

## 12. Como usar este documento

Antes de desenhar qualquer ecrã nos projectos seguintes:
1. Consultar a secção 8 (dashboards) ou 9 (landing) e a checklist da secção 10.
2. Se um efeito for desejado, procurar primeiro na tabela da secção 3 a técnica real, e na secção 7 a compatibilidade.
3. Preferir sempre a solução mais simples (CSS) à mais pesada (JS, GSAP, Three.js).
4. Acrescentar a este ficheiro cada padrão novo que for testado e funcionar, mudando a etiqueta de **[NÃO TESTADO]** para o resultado real.
