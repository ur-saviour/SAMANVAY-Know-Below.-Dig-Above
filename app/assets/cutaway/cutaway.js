(function(){
'use strict';
const status=document.getElementById('status'),stage=document.getElementById('stage');
if(!window.THREE){status.textContent='3D engine unavailable. Reload the viewer or check the bundled viewer assets.';return;}
const T=window.THREE;
let scene,camera,renderer,root,raycaster,mouse,selected=null,mode='3D cutaway',light=true;
let yaw=-0.48,pitch=0.48,distance=15,drag=null,pinch=0;
const groups={};
const colours={Water:0x258ad6,Sewer:0x8b5bc7,Stormwater:0x18a6a0,Electricity:0xe1a928,Telecom:0xd65a9e,Gas:0xe47c32,Borewell:0x26b7a8,Fibre:0x9b8cf4};
const labels={Water:'Water main · illustrative',Sewer:'Sewer line · illustrative',Stormwater:'Stormwater drain · illustrative',Electricity:'Electrical duct · illustrative',Telecom:'Telecom conduit · illustrative',Gas:'Gas pipeline · illustrative',Fibre:'Fibre-optic conduit · illustrative',Borewell:'Borewell · illustrative'};
scene=new T.Scene();scene.background=new T.Color(0xe8f0f2);
camera=new T.PerspectiveCamera(42,1,.1,100);renderer=new T.WebGLRenderer({antialias:true,alpha:false});
renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,2));renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;stage.appendChild(renderer.domElement);
scene.add(new T.HemisphereLight(0xe8f5ff,0x72543a,2.0));
const sun=new T.DirectionalLight(0xffffff,2.1);sun.position.set(-5,12,8);sun.castShadow=true;scene.add(sun);
root=new T.Group();scene.add(root);raycaster=new T.Raycaster();mouse=new T.Vector2();
function mat(color,rough){return new T.MeshStandardMaterial({color:color,roughness:rough===undefined?.85:rough});}
function box(name,x,y,z,sx,sy,sz,color,group){const m=new T.Mesh(new T.BoxGeometry(sx,sy,sz),mat(color));m.position.set(x,y,z);m.castShadow=true;m.receiveShadow=true;(group||root).add(m);return m;}
function pipe(name,x,y,z,length,radius,color,group){
 const m=new T.Mesh(new T.CylinderGeometry(radius,radius,length,18,1),new T.MeshStandardMaterial({color:color,metalness:.18,roughness:.42}));
 m.rotation.z=Math.PI/2;m.position.set(x,y,z);m.castShadow=true;m.receiveShadow=true;m.userData={name:name,kind:name,depth:Math.abs(y).toFixed(1)+' m (visual only)',material:'Illustrative composite',diameter:(radius*200).toFixed(0)+' mm (visual only)',record:'SYNTHETIC DEMO'};
 (group||root).add(m);return m;
}
function makeLabel(text,x,y,z,color,parent){
 const c=document.createElement('canvas');c.width=512;c.height=96;const ctx=c.getContext('2d');ctx.fillStyle='rgba(12,34,48,.82)';ctx.fillRect(0,0,512,96);ctx.fillStyle='#fff';ctx.font='bold 34px Arial';ctx.fillText(text,18,62);
 const tex=new T.CanvasTexture(c);const s=new T.Sprite(new T.SpriteMaterial({map:tex,transparent:true}));s.scale.set(4.1,.78,1);s.position.set(x,y,z);(parent||root).add(s);
}
function build(){
 box('soil',0,-1.65,0,12,3.3,7,0xc59b70);
 box('deep earth',0,-3.65,0,12,1,7,0x98704e);
 for(let i=0;i<5;i++)box('strata',0,-2.2-i*.29,0,12,.025,7,i%2?0xb88c61:0xd0a77a);
 box('road foundation',0,.12,0,12,.28,3.2,0x9e927e);
 box('asphalt',0,.31,0,12,.13,3.25,0x354653);
 box('grass verge',0,.37,-2.25,12,.09,1.15,0x64865a);
 box('grass verge',0,.37,2.25,12,.09,1.15,0x64865a);
 for(let x=-4.5;x<=4.5;x+=1.5)box('road marking',x,.385,0,.75,.015,.045,0xf5f0d8);
 for(let side of [-1,1])for(let x=-4.5;x<=4.5;x+=3){
   box('building',x,1.05,side*3.15,1.7,1.35,1.05,side<0?0xaab8bd:0x93a8b3);
   box('building roof',x,1.75,side*3.15,1.75,.08,1.1,0x6d818b);
 }
 const configs=[
  ['Electricity',-.75,-.72,.12,.065],['Telecom',-.75,-1.05,-.42,.055],
  ['Fibre',-.75,-1.28,-.8,.045],['Water',-.75,-1.65,.58,.14],
  ['Gas',-.75,-2.02,-.1,.09],['Stormwater',-.75,-2.42,.8,.18],['Sewer',-.75,-2.9,-.65,.2]
 ];
 configs.forEach(a=>{const g=new T.Group();root.add(g);for(let x=-4.5;x<=4.5;x+=1.5)pipe(a[0],x,a[2]+Math.sin(x*.45)*.08,a[3],1.8,a[4],colours[a[0]],g);groups[a[0]]=g;makeLabel(a[0],4.6,a[2],a[3],colours[a[0]],g);});
 const bore=new T.Group();root.add(bore);const shaft=new T.Mesh(new T.CylinderGeometry(.08,.08,2.4,16),mat(colours.Borewell));shaft.position.set(4.3,-1.6,2.4);shaft.userData={name:'Borewell',kind:'Borewell',depth:'Illustrative only',material:'Illustrative composite',diameter:'Visual only',record:'SYNTHETIC DEMO'};bore.add(shaft);groups.Borewell=bore;
 makeLabel('BOREWELL',4.3,-.5,2.4,colours.Borewell,bore);
}
build();
function resize(){const w=stage.clientWidth,h=stage.clientHeight;camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h,false);}
window.addEventListener('resize',resize);resize();
function cameraUpdate(){
 const target=new T.Vector3(0,-1,0);
 if(mode==='2D plan'){camera.position.set(0,12,0.001);camera.up.set(0,0,-1);camera.lookAt(0,-1,0);}
 else{camera.up.set(0,1,0);camera.position.set(target.x+distance*Math.sin(yaw)*Math.cos(pitch),target.y+distance*Math.sin(pitch),target.z+distance*Math.cos(yaw)*Math.cos(pitch));camera.lookAt(target);}
}
function updateTheme(){document.body.classList.toggle('dark',!light);scene.background=new T.Color(light?0xe8f0f2:0x102332);}
function setMode(m){mode=m;document.getElementById('plan').classList.toggle('active',m==='2D plan');document.getElementById('cut').classList.toggle('active',m!=='2D plan');cameraUpdate();}
document.getElementById('plan').onclick=()=>{setMode('2D plan');if(window.Samanvay)window.Samanvay.postMessage(JSON.stringify({type:'mode',mode:'2D plan'}));};
document.getElementById('cut').onclick=()=>setMode('3D cutaway');
function update(data){
 if(!data)return;
 if(data.mode)setMode(data.mode);
 if(typeof data.light==='boolean'){light=data.light;updateTheme();}
 if(Array.isArray(data.layers)){Object.keys(groups).forEach(k=>groups[k].visible=data.layers.includes(k));}
}
window.samanvayUpdate=update;
function selectAt(e){
 const r=renderer.domElement.getBoundingClientRect();mouse.x=((e.clientX-r.left)/r.width)*2-1;mouse.y=-((e.clientY-r.top)/r.height)*2+1;raycaster.setFromCamera(mouse,camera);
 const candidates=[];Object.keys(groups).forEach(k=>{if(groups[k].visible)groups[k].traverse(o=>{if(o.isMesh&&o.userData.name&&o.visible)candidates.push(o);});});
 const hit=raycaster.intersectObjects(candidates,false)[0];if(!hit)return;
 selected=hit.object;const d=selected.userData;document.getElementById('assetName').textContent=d.name||'Demo asset';
 document.getElementById('assetMeta').textContent=(d.diameter||'Illustrative')+' · '+(d.depth||'depth not surveyed')+' · '+(d.record||'DEMO');
 if(window.Samanvay)window.Samanvay.postMessage(JSON.stringify({type:'record_selected',name:d.name||'Demo asset',record:d.record||'SYNTHETIC DEMO'}));
}
const activePointers=new Map();let pinchDistance=0;
renderer.domElement.addEventListener('pointerdown',e=>{
 activePointers.set(e.pointerId,{x:e.clientX,y:e.clientY});
 renderer.domElement.setPointerCapture(e.pointerId);
 if(activePointers.size===1)drag={x:e.clientX,y:e.clientY,moved:false};
 else if(activePointers.size===2){if(drag)drag.moved=true;const p=[...activePointers.values()];pinchDistance=Math.hypot(p[0].x-p[1].x,p[0].y-p[1].y);}
});
renderer.domElement.addEventListener('pointermove',e=>{
 if(!activePointers.has(e.pointerId))return;
 activePointers.set(e.pointerId,{x:e.clientX,y:e.clientY});
 if(activePointers.size>=2){
  const p=[...activePointers.values()].slice(0,2),d=Math.hypot(p[0].x-p[1].x,p[0].y-p[1].y);
  if(drag)drag.moved=true;
  distance=Math.max(8,Math.min(25,distance+(pinchDistance-d)*.035));pinchDistance=d;cameraUpdate();return;
 }
 if(!drag||mode==='2D plan')return;
 const dx=e.clientX-drag.x,dy=e.clientY-drag.y;
 if(Math.abs(dx)+Math.abs(dy)>2)drag.moved=true;
 yaw-=dx*.008;pitch=Math.max(.12,Math.min(1.25,pitch+dy*.006));
 drag.x=e.clientX;drag.y=e.clientY;cameraUpdate();
});
function finishPointer(e){
 const wasLast=activePointers.size===1;
 activePointers.delete(e.pointerId);
 if(wasLast){if(drag&&!drag.moved)selectAt(e);drag=null;}
 else if(activePointers.size===1){const p=[...activePointers.values()][0];if(drag){drag.x=p.x;drag.y=p.y;drag.moved=true;}}
}
renderer.domElement.addEventListener('pointerup',finishPointer);
renderer.domElement.addEventListener('pointercancel',e=>{
 activePointers.delete(e.pointerId);drag=null;pinchDistance=0;
});
renderer.domElement.addEventListener('wheel',e=>{distance=Math.max(8,Math.min(25,distance+e.deltaY*.012));cameraUpdate();},{passive:true});
function animate(){requestAnimationFrame(animate);renderer.render(scene,camera);}cameraUpdate();animate();
status.style.display='none';
window.samanvayUpdate({mode:'3D cutaway',layers:Object.keys(groups),light:true});
})();