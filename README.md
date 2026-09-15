# vision-based-rgp-devcontainer

DevContainer alapú fejlesztői környezet a **"Gépi látás alapú robotikai megfogási probléma vizsgálata"** című diplomamunkához, amely a BME 5G Laborjában készül.

## Projekt háttere

Az elmúlt években számos kutatás-fejlesztési projekt indult az 5. generációs mobilhálózatok (5G) területén. Ennek részeként a BME-n létrejött az **5G Labor**, ahol az egyetem hallgatói és kutatói jelentős ipari partnerekkel együttműködésben végeznek kutatásokat és fejlesztéseket.

A diplomamunka feladata az 5G Laborban található, 6 szabadságfokú (6-DoF) robotkarhoz kapcsolódik. A cél, hogy a robotkar környezetében elhelyezkedő tetszőleges objektumok esetén automatikusan meghatározásra kerüljenek a megfogási pontok. A rendszer egy kamerarendszer segítségével érzékeli az objektumok helyzetét és orientációját, majd ezek alapján számítja ki a megfelelő megfogási pontokat.

### A feladat az alábbiakra terjed ki

- A szakirodalomban található megfogási probléma megoldására kidolgozott módszerek vizsgálata
- Megfogási pontokat becslő módszer implementálása **ROS2** keretrendszerben
- A robotkar vezérlésének megvalósítása a **MoveIt** mozgástervező módszerei alapján
- A robotkar környezetében lévő objektumok gépi látás alapú felismerése
- Az elkészült rendszer működésének demonstrálása valós környezetben

## Mérési elrendezés

- **Robotkar:** Universal Robots UR5e (6-DoF)
- **Megfogó:** OnRobot RG2 (max. nyílás: 110 mm, ujjszélesség: ~4 mm, kéz mélység: 42,6 mm)
- **Kamera:** Intel RealSense D435, mennyezetre szerelve egy pingpongasztal fölött
- A világ (`world`) koordináta-rendszer középpontja a pingpongasztal közepe

## Szoftver stack

A DevContaineren belül a következő repository-k vannak telepítve:

| Repo                      | Forrás                                                                 | Szerepe                         |
| ------------------------- | ---------------------------------------------------------------------- | ------------------------------- |
| `realsense-ros`           | [realsenseai](https://github.com/realsenseai/realsense-ros)            | RealSense ROS2 driver           |
| `librealsense`            | [realsenseai](https://github.com/realsenseai/librealsense)             | RealSense SDK                   |
| `dgl_ros`                 | [tecsizsv fork](https://github.com/tecsizsv/dgl_ros) (`bme-5g-dev` ág) | GPD–ROS2 összekötő csomagok     |
| `gpd`                     | [tecsizsv fork](https://github.com/tecsizsv/gpd) (`bme-5g-dev` ág)     | Grasp Pose Detection algoritmus |
| `moveit_task_constructor` | [moveit](https://github.com/moveit/moveit_task_constructor)            | MoveIt mozgástervezés           |

**Egyéb komponensek:** PCL, RViz2

**Konténerizáció:** Docker + VS Code Dev Containers, ROS2 (Humble-ről Kilted Kaiju-ra migrálva).

## Használatba vétel

1. Klónozás után nyisd meg a repót VS Code-ban, majd **Rebuild and Reopen in Container**. Ez automatikusan lefuttatja a `.devcontainer/setup.sh`-t, ami a `colcon build`-ot is elvégzi — külön build lépés normál esetben nem szükséges.
2. Ha a setup valamiért nem futott le teljesen (pl. megszakadt a build), manuálisan is elindítható a repo gyökeréből:
   ```bash
   bash .devcontainer/setup.sh
   ```

## Használat

### Rendszer indítása (két terminálban)

**1. terminál** — a szükséges node-ok elindítása (válassz egyet):

- Teljes pipeline egyszerre (kamera, RViz, a kamera és a `world` keret közötti statikus transzformáció, valamint a GPD action szerver):
  ```bash
  ros2 launch dgl_ros_models big_launch.py
  ```
- Vagy csak a GPD node önállóan, debug célra:
  ```bash
  ros2 run dgl_ros_models gpd --ros-args \
    -p rc_topic0:=/camera/camera/depth/color/points \
    -p gpd_config_path:=src/dgl_ros/dgl_ros_models/config/gpd_config.yaml
  ```
  *(a `gpd_config_path` a workspace gyökeréhez relatív — a saját klónod útvonalától függetlenül működik)*

**2. terminál** — a megfogás-becslés action elindítása. Ezt jelenleg mindig külön kell indítani, a `big_launch` nem triggereli automatikusan:

```bash
ros2 action send_goal --feedback /sample_grasp_poses dgl_ros_interfaces/action/SampleGraspPoses "{action_name: 'sample_grasp_poses'}"
```

Ennek hatására a `dgl_ros_models` csomagban lévő `gpd.cpp` kiszámítja a legjobb lehetséges megfogásokat, valamint azok pozícióját és orientációját a világ koordináta-rendszerben.

### GPD önálló tesztelése (host gépen)

```bash
gpd/build/detect_grasps gpd/cfg/eigen_params.cfg gpd/tutorials/krylon.pcd
```

## Hiba esetén mit lehet tenni

- **`colcon build` elakad vagy furcsa hibákat dob:** töröld a build mappákat, és építsd újra tisztán:
  ```bash
  rm -rf build/ install/ log/
  colcon build --symlink-install
  ```
- **"Library GPD not found" hiba a `dgl_ros_models` buildelésekor:** hiányzik a `sudo make install` lépés a GPD build könyvtárában — ezt pótolni kell.
- **A devcontainer nem indul el rendesen / a setup nem futott le automatikusan:** futtasd manuálisan a `bash .devcontainer/setup.sh`-t a repo gyökeréből.

## Eddigi eredmények

- A DevContaineres környezet összeállítva, a szükséges függőségek rögzítve a Docker image-ben a hordozhatóság érdekében
- `big_launch` launch file elkészült (kamera, RViz, statikus transzformáció, GPD action szerver)
- Az action elindítására a `dgl_ros_models`-beli `gpd.cpp` kiszámítja a legjobb megfogási pontokat és azok pozícióját/orientációját a világ koordinátában
- A host gépen futtatott GPD segítségével sikeresen behangolva a `gpd_config.yaml` paraméterei, valós és értelmes megfogási eredményekkel

## Továbbfejlesztési tervek / To-do

- `big_launch` kiegészítése úgy, hogy az action indítását is automatikusan elvégezze (jelenleg mindig külön terminálból kell)
- MoveIt-alapú robotmozgás-vezérlés integrálása
- Objektumfelismerés / szegmentáció megvalósítása
- A GPD workspace bounding box paramétereinek felülvizsgálata/dokumentálása úgy, hogy illeszkedjenek a kamera optikai koordináta-rendszeréhez (Z előre, nem felfelé mutat) — eltérés esetén minden pont csendben kiszűrődik, és nulla megfogási jelölt születik
- A PCL viewer containeren belüli hibájának megoldása, hogy a pontfelhő-kiértékelés ne a host gépen kelljen, hogy fusson

---

*Ez a repó a diplomamunka fejlesztői környezetét (DevContainer) tartalmazza. A szakdolgozat szövege a `vision-based-rgp` repóban készül.*