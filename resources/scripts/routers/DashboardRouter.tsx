import React, { lazy } from 'react';
import { NavLink, Route, Switch } from 'react-router-dom';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import {
    faCreditCard,
    faFlask,
    faInfoCircle,
    faLayerGroup,
    faNewspaper,
    faTrophy,
} from '@fortawesome/free-solid-svg-icons';
import { useStoreState } from 'easy-peasy';
import styled from 'styled-components/macro';
import tw from 'twin.macro';
import NavigationBar from '@/components/NavigationBar';
import DashboardContainer from '@/components/dashboard/DashboardContainer';
import { NotFound } from '@/components/elements/ScreenBlock';
import TransitionRouter from '@/TransitionRouter';
import SubNavigation from '@/components/elements/SubNavigation';
import { useLocation } from 'react-router';
import Spinner from '@/components/elements/Spinner';
import routes from '@/routers/routes';

const TrophiesContainer = lazy(() => import('@/components/touchdown/TrophiesContainer'));
const ServicesContainer = lazy(() => import('@/components/touchdown/ServicesContainer'));
const DevBlogsContainer = lazy(() => import('@/components/touchdown/DevBlogsContainer'));
const AboutContainer = lazy(() => import('@/components/touchdown/AboutContainer'));
const DevLabContainer = lazy(() => import('@/components/touchdown/DevLabContainer'));

// The dedicated "About Touch Down Hosting" tab — styled as a White/Orange pill
// to stand apart from the regular navigation links.
const AboutPill = styled(NavLink)`
    && {
        ${tw`rounded-full my-2 py-1 px-4 bg-white font-semibold`};
        color: var(--tdh-brand-600);
        box-shadow: none;

        &:hover,
        &.active {
            background: linear-gradient(135deg, var(--tdh-brand-500) 0%, var(--tdh-brand-600) 100%);
            color: #ffffff;
            box-shadow: 0 0 14px var(--tdh-glow);
        }
    }
`;

export default () => {
    const location = useLocation();
    const devFeatures = useStoreState((state) => state.settings.data?.touchdown?.devFeatures) || false;

    return (
        <>
            <NavigationBar />
            <SubNavigation>
                <div>
                    <NavLink to={'/'} exact>
                        <FontAwesomeIcon icon={faLayerGroup} css={tw`mr-2`} />
                        Dashboard
                    </NavLink>
                    <NavLink to={'/trophies'}>
                        <FontAwesomeIcon icon={faTrophy} css={tw`mr-2`} />
                        Trophies
                    </NavLink>
                    <NavLink to={'/services'}>
                        <FontAwesomeIcon icon={faCreditCard} css={tw`mr-2`} />
                        Services
                    </NavLink>
                    <NavLink to={'/dev-blogs'}>
                        <FontAwesomeIcon icon={faNewspaper} css={tw`mr-2`} />
                        Dev-Blogs
                    </NavLink>
                    <AboutPill to={'/about'}>
                        <FontAwesomeIcon icon={faInfoCircle} css={tw`mr-2`} />
                        About Touch Down Hosting
                    </AboutPill>
                    {devFeatures && (
                        <NavLink to={'/dev-lab'}>
                            <FontAwesomeIcon icon={faFlask} css={tw`mr-2`} />
                            Dev Lab
                        </NavLink>
                    )}
                </div>
            </SubNavigation>
            {location.pathname.startsWith('/account') && (
                <SubNavigation>
                    <div>
                        {routes.account
                            .filter((route) => !!route.name)
                            .map(({ path, name, exact = false }) => (
                                <NavLink key={path} to={`/account/${path}`.replace('//', '/')} exact={exact}>
                                    {name}
                                </NavLink>
                            ))}
                    </div>
                </SubNavigation>
            )}
            <TransitionRouter>
                <React.Suspense fallback={<Spinner centered />}>
                    <Switch location={location}>
                        <Route path={'/'} exact>
                            <DashboardContainer />
                        </Route>
                        <Route path={'/trophies'} exact>
                            <TrophiesContainer />
                        </Route>
                        <Route path={'/services'} exact>
                            <ServicesContainer />
                        </Route>
                        <Route path={'/dev-blogs'} exact>
                            <DevBlogsContainer />
                        </Route>
                        <Route path={'/about'} exact>
                            <AboutContainer />
                        </Route>
                        <Route path={'/dev-lab'} exact>
                            <DevLabContainer />
                        </Route>
                        {routes.account.map(({ path, component: Component }) => (
                            <Route key={path} path={`/account/${path}`.replace('//', '/')} exact>
                                <Component />
                            </Route>
                        ))}
                        <Route path={'*'}>
                            <NotFound />
                        </Route>
                    </Switch>
                </React.Suspense>
            </TransitionRouter>
        </>
    );
};
