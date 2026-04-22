import { Suspense, useState, useEffect, useRef } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { 
    OrbitControls, 
    PerspectiveCamera, 
    Text, 
    Environment, 
    KeyboardControls, 
    useKeyboardControls,
    Billboard
} from '@react-three/drei';
import * as THREE from 'three';
import { gsap } from 'gsap';

// --- DYNAMIC CONFIG ---
const getParams = () => {
    const urlParams = new URLSearchParams(window.location.search);
    return {
        server: urlParams.get('server') || 'http://localhost:5001',
        token: urlParams.get('token') || ''
    };
};

const params = getParams();

// --- DESIGN TOKENS ---

// --- UTILS ---
const colorMap: { [key: string]: string } = {
    'red': '#ff0000',
    'blue': '#0000ff',
    'green': '#00ff00',
    'yellow': '#ffff00',
    'white': '#ffffff',
    'black': '#000000',
    'pink': '#ff00ff',
    'orange': '#ffa500',
    'navy': '#000080',
    'sky': '#87ceeb',
    'olive': '#808000',
    'lavender': '#e6e6fa',
    'violet': '#ee82ee',
    'plum': '#8e4585',
    'rust': '#b7410e',
    'chocolate': '#d2691e',
    'brown': '#8b4513',
    'maroon': '#800000',
    'peacock': '#008080',
    'grey': '#808080',
    'ash': '#b2beb5',
    'sandal': '#f1e5ac',
    'skin': '#fce5cd',
    'coral': '#ff7f50',
    'burgundy': '#800020'
};

const getSafeColor = (c: any) => {
    if (!c) return '#ffffff';
    let str = String(c).toLowerCase().trim();
    
    // Cleanup complex strings like "D.PINK-5355" or "S.BLUE-202"
    // 1. Remove anything after a hyphen
    str = str.split('-')[0];
    // 2. Remove "D." or "L." or "DK." or "LT." prefixes
    str = str.replace(/^(d\.|l\.|dk\.|lt\.)/, '');
    
    // 3. Exact match
    if (colorMap[str]) return colorMap[str];
    
    // 4. Keyword search
    for (const key in colorMap) {
        if (str.includes(key)) return colorMap[key];
    }
    
    return str.startsWith('#') ? str : '#ffffff';
};

// --- COMPONENTS ---

const CameraController = ({ targetPosition, isMoving }: { targetPosition: [number, number, number], isMoving: boolean }) => {
  const { camera, controls } = useThree() as any;
  useEffect(() => {
    if (isMoving && controls) {
      gsap.to(controls.target, { x: targetPosition[0], y: 4, z: targetPosition[2], duration: 1.2, ease: "power2.inOut" });
      gsap.to(camera.position, { x: targetPosition[0] + 12, y: 12, z: targetPosition[2] + 18, duration: 1.2, ease: "power2.inOut" });
    }
  }, [targetPosition, isMoving]);
  return null;
};

const Player = () => {
    const [, getKeys] = useKeyboardControls();
    const velocity = useRef(new THREE.Vector3());
    const direction = useRef(new THREE.Vector3());
    useFrame((state) => {
        const { forward, backward, left, right } = getKeys();
        if (forward || backward || left || right) {
            direction.current.z = Number(forward) - Number(backward);
            direction.current.x = Number(right) - Number(left);
            direction.current.normalize();
            velocity.current.z -= direction.current.z * 0.3;
            velocity.current.x -= direction.current.x * 0.3;
            state.camera.position.x += velocity.current.x;
            state.camera.position.z += velocity.current.z;
            velocity.current.multiplyScalar(0.9);
        }
    });
    return null;
};

const StockBox = ({ weight, color, position }: { weight: any; color: any; position: [number, number, number] }) => {
    const boxColor = getSafeColor(color);
    return (
        <group position={position}>
            <mesh castShadow receiveShadow>
                <boxGeometry args={[2.0, 1.2, 1.8]} />
                <meshStandardMaterial color={boxColor} roughness={0.4} metalness={0.7} />
            </mesh>
            <Billboard position={[0, 1.3, 0]}>
                <Text 
                    fontSize={0.5} 
                    color="black" 
                    fontWeight="900"
                    outlineWidth={0.08}
                    outlineColor="white"
                    anchorX="center"
                    anchorY="middle"
                >
                    {weight ? `${Number(weight).toFixed(1)}kg` : '0kg'}
                </Text>
            </Billboard>
        </group>
    );
};

const RackUnit = ({ id, position, occupancy, onSlotClick, isHighlighted }: { id: string; position: [number, number, number], occupancy: any, onSlotClick: (rack: string, slot: string) => void, isHighlighted: boolean }) => {
    const levels = [1, 2, 3, 4];
    return (
        <group position={position}>
            {/* Posts */}
            {[[-1.2, -1], [-1.2, 1], [1.2, -1], [1.2, 1]].map(([x, z], i) => (
                <mesh key={i} position={[x, 5, z]}>
                    <boxGeometry args={[0.2, 10, 0.2]} />
                    <meshStandardMaterial color={isHighlighted ? "#00a8ff" : "#2f3640"} />
                </mesh>
            ))}
            {levels.map((lvl, l) => {
                const sKey = lvl.toString();
                const stock = occupancy && occupancy[sKey] ? occupancy[sKey] : [];
                return (
                    <group key={lvl} position={[0, l * 2.3, 0]}>
                        <mesh position={[0, 0, 0]}>
                            <boxGeometry args={[2.5, 0.1, 2.1]} />
                            <meshStandardMaterial color="#7f8c8d" />
                        </mesh>
                        <group position={[0, 0.8, 0]} onClick={(e) => { e.stopPropagation(); onSlotClick(id, sKey); }}>
                            <mesh onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'auto')}>
                                <boxGeometry args={[2.5, 2.0, 2.1]} /><meshStandardMaterial transparent opacity={0} />
                            </mesh>
                            {stock.slice(0, 1).map((item: any, idx: number) => (
                                <StockBox key={idx} weight={item.weight} color={item.colour} position={[0, 0, 0]} />
                            ))}
                            <Text position={[0, -0.6, 1.1]} fontSize={0.3} color="#ecf0f1" fontWeight="bold">{id}-{sKey}</Text>
                        </group>
                    </group>
                );
            })}
        </group>
    );
};

export default function App() {
    const [warehouseData, setWarehouseData] = useState<any>(null);
    const [baseUrl, setBaseUrl] = useState(params.server);
    const [selectedRackId, setSelectedRackId] = useState<string | null>(null);
    const [camPos, setCamPos] = useState<[number, number, number]>([0, 0, 0]);
    const [isMoving, setIsMoving] = useState(false);

    const pullData = (url: string) => {
        const cleanUrl = url.replace(/\/$/, "");
        fetch(`${cleanUrl}/api/inventory/reports/warehouse-3d`)
            .then(res => { if(!res.ok) throw new Error(); return res.json(); })
            .then(data => { setWarehouseData(data); setBaseUrl(cleanUrl); })
            .catch(() => { if (url !== 'http://localhost:5001') pullData('http://localhost:5001'); });
    };

    useEffect(() => {
        pullData(params.server);
        const tid = setInterval(() => pullData(baseUrl), 5000);
        return () => clearInterval(tid);
    }, [baseUrl]);

    useEffect(() => {
        const handleMsg = (e: MessageEvent) => {
            if (e.data?.type === 'move_to_slot' && warehouseData?.racks) {
                const i = warehouseData.racks.indexOf(e.data.rackId);
                if (i !== -1) {
                    setSelectedRackId(e.data.rackId);
                    const rpr = Math.ceil(warehouseData.racks.length / 2);
                    const ri = Math.floor(i / rpr); const ci = i % rpr;
                    setCamPos([ci * 8 - (rpr * 4), 0, ri * 15 - 7.5]);
                    setIsMoving(true); 
                    setTimeout(() => setIsMoving(false), 1500);
                }
            }
        };
        window.addEventListener('message', handleMsg);
        return () => window.removeEventListener('message', handleMsg);
    }, [warehouseData]);

    return (
        <KeyboardControls map={[{ name: "forward", keys: ["ArrowUp", "W"] },{ name: "backward", keys: ["ArrowDown", "S"] },{ name: "left", keys: ["ArrowLeft", "A"] },{ name: "right", keys: ["ArrowRight", "D"] }]}>
            <div style={{ width: '100vw', height: '100vh', background: '#2c3e50', display: 'flex', flexDirection: 'column' }}>
                <div style={{ padding: '8px 20px', background: '#34495e', display: 'flex', justifyContent: 'space-between', borderBottom: '2px solid #2c3e50' }}>
                    <span style={{ color: '#00a8ff', fontWeight: 'bold' }}>3D WMS LIVE</span>
                    <span style={{ color: '#2ecc71', fontSize: '9px' }}>SYNC: {baseUrl}</span>
                </div>
                <div style={{ flex: 1 }}>
                    <Canvas shadows>
                        <PerspectiveCamera makeDefault position={[30, 30, 30]} fov={50} />
                        <OrbitControls makeDefault enableDamping />
                        <CameraController targetPosition={camPos} isMoving={isMoving} />
                        <Player />
                        <ambientLight intensity={1.0} />
                        <pointLight position={[50, 50, 50]} intensity={3} />
                        <Suspense fallback={null}>
                            {warehouseData?.racks?.map((r: string, i: number) => {
                                const rpr = Math.ceil(warehouseData.racks.length / 2);
                                const ri = Math.floor(i / rpr); const ci = i % rpr;
                                return <RackUnit key={r} id={r} position={[ci * 8 - (rpr * 4), 0, ri * 15 - 7.5]} occupancy={warehouseData.occupancy[r]} isHighlighted={selectedRackId === r} onSlotClick={(rid, s) => {
                                    setSelectedRackId(rid);
                                    window.parent.postMessage({ type: 'slot_selected', rackId: rid, slotId: s }, '*');
                                }} />;
                            })}
                            <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.05, 0]} receiveShadow><planeGeometry args={[2000, 2000]} /><meshStandardMaterial color="#2c3e50" /></mesh>
                            <gridHelper args={[2000, 100, "#34495e", "#34495e"]} />
                            <Environment preset="city" />
                        </Suspense>
                    </Canvas>
                </div>
            </div>
        </KeyboardControls>
    );
}
